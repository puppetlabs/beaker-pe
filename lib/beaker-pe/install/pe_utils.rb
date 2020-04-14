[ 'aio_defaults', 'puppet_utils', 'windows_utils' ].each do |lib|
    require "beaker-puppet/install_utils/#{lib}"
end
require 'beaker-pe/install/feature_flags'
require "beaker-answers"
require "timeout"
require "json"
require "deep_merge"

module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods to help installing/upgrading PE builds - including Higgs installs
      #
      # To mix this is into a class you need the following:
      # * a method *hosts* that yields any hosts implementing
      #   {Beaker::Host}'s interface to act upon.
      # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
      # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
      #   {Beaker::Host}'s interface to act upon
      # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
      module PEUtils
        include AIODefaults
        include PEDefaults
        include PuppetUtils
        include WindowsUtils

        # Version of PE when we switched from legacy installer to MEEP.
        MEEP_CUTOVER_VERSION = '2016.2.0'
        # Version of PE when we switched to using meep for classification
        # instead of PE node groups
        MEEP_CLASSIFICATION_VERSION = '2018.2.0'
        # PE-18799 temporary default used for meep classification check while
        # we navigate the switchover.
        # PE-18718 switch flag to true once beaker-pe, beaker-answers,
        # beaker-pe-large-environments and pe_acceptance_tests are ready
        DEFAULT_MEEP_CLASSIFICATION = false
        # Version of PE in which PE is managing the agent service
        MANAGE_PUPPET_SERVICE_VERSION = '2018.1.0'

        MEEP_DATA_DIR = '/etc/puppetlabs/enterprise'
        PE_CONF_FILE = "#{MEEP_DATA_DIR}/conf.d/pe.conf"
        NODE_CONF_PATH = "#{MEEP_DATA_DIR}/conf.d/nodes"
        BEAKER_MEEP_TMP = "pe_conf"

        # @!macro [new] common_opts
        #   @param [Hash{Symbol=>String}] opts Options to alter execution.
        #   @option opts [Boolean] :silent (false) Do not produce log output
        #   @option opts [Array<Fixnum>] :acceptable_exit_codes ([0]) An array
        #     (or range) of integer exit codes that should be considered
        #     acceptable.  An error will be thrown if the exit code does not
        #     match one of the values in this list.
        #   @option opts [Boolean] :accept_all_exit_codes (false) Consider all
        #     exit codes as passing.
        #   @option opts [Boolean] :dry_run (false) Do not actually execute any
        #     commands on the SUT
        #   @option opts [String] :stdin (nil) Input to be provided during command
        #     execution on the SUT.
        #   @option opts [Boolean] :pty (false) Execute this command in a pseudoterminal.
        #   @option opts [Boolean] :expect_connection_failure (false) Expect this command
        #     to result in a connection failure, reconnect and continue execution.
        #   @option opts [Hash{String=>String}] :environment ({}) These will be
        #     treated as extra environment variables that should be set before
        #     running the command.

        #Sort array of hosts so that it has the correct order for PE installation based upon each host's role
        #@param subset [Array<Host>] An array of hosts to sort, defaults to global 'hosts' object
        # @example
        #  h = sorted_hosts
        #
        # @note Order for installation should be
        #        First : master
        #        Second: database host (if not same as master)
        #        Third:  dashboard (if not same as master or database)
        #        Fourth: everything else
        #
        # @!visibility private
        def sorted_hosts subset = hosts
          special_nodes = []
          [master, database, dashboard].uniq.each do |host|
            special_nodes << host if host != nil && subset.include?(host)
          end
          real_agents = agents - special_nodes
          real_agents = real_agents.delete_if{ |host| !subset.include?(host) }
          special_nodes + real_agents
        end

        # If host or opts has the :use_puppet_ca_cert flag set, then push the master's
        # ca cert onto the given host at /etc/puppetlabs/puppet/ssl/certs/ca.pem.
        #
        # This in turn allows +frictionless_agent_installer_cmd+ to generate
        # an install which references the cert to verify the master when downloading
        # resources.
        def install_ca_cert_on(host, opts)
          if host[:use_puppet_ca_cert] || opts[:use_puppet_ca_cert]
            @cert_cache_dir ||= Dir.mktmpdir("master_ca_cert")
            local_cert_copy = "#{@cert_cache_dir}/ca.pem"
            step "Copying master ca.pem to agent for secure frictionless install" do
              agent_ca_pem_dir = "#{host['puppetpath']}/ssl/certs"
              master_ca_pem_path = "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
              scp_from(master, master_ca_pem_path , @cert_cache_dir) unless File.exist?(local_cert_copy)
              on(host, "mkdir -p #{agent_ca_pem_dir}")
              scp_to(host, local_cert_copy, agent_ca_pem_dir)
            end
          end
        end

        # Return agent nodes with 'lb_connect' role that are not loadbalancers
        def loadbalancer_connecting_agents
          lb_connect_nodes = select_hosts(roles: ['lb_connect'])
          lb_connect_agents = lb_connect_nodes.reject { |h| h['roles'].include?('loadbalancer')}
        end

        # Returns true if loadbalncer exists and is configured with 'lb_connect' role
        def lb_connect_loadbalancer_exists?
          if any_hosts_as?('loadbalancer')
            lb_node = select_hosts(roles: ['loadbalancer'])
            lb_node.first['roles'].include?('lb_connect')
          end
        end

        #Returns loadbalancer if host is an agent and loadbalancer has lb_connect role
        #@param [Host] agent host with lb_connect role
        def get_lb_downloadhost(host)
          downloadhost = master
          if !host['roles'].include?('loadbalancer') &&  lb_connect_loadbalancer_exists?
            downloadhost = loadbalancer
          end
          downloadhost
        end

        #Remove client_datadir on the host
        #@param [Host] the host
        def remove_client_datadir(host)
          client_datadir = host.puppet['client_datadir']
          on(host, "rm -rf #{client_datadir}")
        end

        #Return true if tlsv1 protocol needs to be enforced
        #param [Host] the host
        def require_tlsv1?(host)
          tlsv1_platforms = [/aix/, /el-5/, /solaris-1[0,1]-[i,x]/, /sles-11/,/windows-2008/]
          return tlsv1_platforms.any? {|platform_regex| host['platform'] =~ platform_regex}
        end

        # Generate the command line string needed to from a frictionless puppet-agent
        # install on this host in a PE environment.
        #
        # @param [Host] host The host to install puppet-agent onto
        # @param [Hash] opts The full beaker options
        # @option opts [Boolean] :use_puppet_ca_cert (false) if true the
        #   command will reference the local puppet ca cert to verify the master
        #   when obtaining the installation script
        # @param [String] pe_version The PE version string for capabilities testing
        # @return [String] of the commands to be executed for the install
        def frictionless_agent_installer_cmd(host, opts, pe_version)
          # PE 3.4 introduced the ability to pass in config options to the bash
          # script in the form of <section>:<key>=<value>
          frictionless_install_opts = []
          if host.has_key?('frictionless_options') and !  version_is_less(pe_version, '3.4.0')
            # since we have options to pass in, we need to tell the bash script
            host['frictionless_options'].each do |section, settings|
              settings.each do |key, value|
                frictionless_install_opts << "#{section}:#{key}=#{value}"
              end
            end
          end

          # PE 2018.1.0 introduced a pe_repo flag that will determine what happens during the frictionless install
          # Current support in beaker-pe is for:
          # --puppet-service-debug, when running puppet service enable, the debug flag is passed into puppt service
          if (host[:puppet_service_debug_flag] == true and ! version_is_less(pe_version, '2018.1.0'))
            frictionless_install_opts << '--puppet-service-debug'
          end

          # If this is an agent node configured to connect to the loadbalancer
          # using 'lb_connect' role, then use loadbalancer in the download url
          # instead of master
          downloadhost = master
          if host['roles'].include?('lb_connect')
            downloadhost = get_lb_downloadhost(host)
          end

          pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -x' : ''
          use_puppet_ca_cert = host[:use_puppet_ca_cert] || opts[:use_puppet_ca_cert]

          if host['platform'] =~ /windows/ then
            if use_puppet_ca_cert
              frictionless_install_opts << '-UsePuppetCA'
              cert_validator = %Q{\\$callback = {param(\\$sender,[System.Security.Cryptography.X509Certificates.X509Certificate]\\$certificate,[System.Security.Cryptography.X509Certificates.X509Chain]\\$chain,[System.Net.Security.SslPolicyErrors]\\$sslPolicyErrors);\\$CertificateType=[System.Security.Cryptography.X509Certificates.X509Certificate2];\\$CACert=\\$CertificateType::CreateFromCertFile('#{host['puppetpath']}/ssl/certs/ca.pem') -as \\$CertificateType;\\$chain.ChainPolicy.ExtraStore.Add(\\$CACert);return \\$chain.Build(\\$certificate)};[Net.ServicePointManager]::ServerCertificateValidationCallback = \\$callback}
            else
              cert_validator = '[Net.ServicePointManager]::ServerCertificateValidationCallback = {\\$true}'
            end
            if version_is_less(pe_version, '2019.1.0') || require_tlsv1?(host) then
              protocol_to_use =''
            else
              protocol_to_use = '[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
            end

            cmd = %Q{powershell -c "cd #{host['working_dir']};#{protocol_to_use};#{cert_validator};\\$webClient = New-Object System.Net.WebClient;\\$webClient.DownloadFile('https://#{downloadhost}:8140/packages/current/install.ps1', '#{host['working_dir']}/install.ps1');#{host['working_dir']}/install.ps1 -verbose #{frictionless_install_opts.join(' ')}"}
          else
            curl_opts = %w{-O}
            if version_is_less(pe_version, '2019.1.0') || require_tlsv1?(host)
              curl_opts << '--tlsv1'
            end
            if use_puppet_ca_cert
              curl_opts << '--cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem'
            elsif host['platform'] !~ /aix/
              curl_opts << '-k'
            end

            cmd = "FRICTIONLESS_TRACE='true'; export FRICTIONLESS_TRACE; cd #{host['working_dir']} && curl #{curl_opts.join(' ')} https://#{downloadhost}:8140/packages/current/install.bash && bash#{pe_debug} install.bash #{frictionless_install_opts.join(' ')}".strip
          end

          return cmd
        end

        #Create the PE install command string based upon the host and options settings
        # @param [Host] host The host that PE is to be installed on
        #                    For UNIX machines using the full PE installer, the host object must have the 'pe_installer' field set correctly.
        # @param [Hash{Symbol=>String}] opts The options
        # @option opts [String]  :pe_ver Default PE version to install or upgrade to
        #                          (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :pe_debug (false) Should we run the installer in debug mode?
        # @option opts [Boolean] :interactive (false) Should we run the installer in interactive mode?
        # @example
        #      on host, "#{installer_cmd(host, opts)} -a #{host['working_dir']}/answers"
        # @api private
        def installer_cmd(host, opts)
          version = host['pe_ver'] || opts[:pe_ver]
          # Frictionless install didn't exist pre-3.2.0, so in that case we fall
          # through and do a regular install.
          if host['roles'].include? 'frictionless' and ! version_is_less(version, '3.2.0')
            frictionless_agent_installer_cmd(host, opts, version)
          elsif host['platform'] =~ /osx/
            version = host['pe_ver'] || opts[:pe_ver]
            pe_debug = host[:pe_debug] || opts[:pe_debug] ? ' -verboseR' : ''
            "cd #{host['working_dir']} && hdiutil attach #{host['dist']}.dmg && installer#{pe_debug} -pkg /Volumes/puppet-enterprise-#{version}/puppet-enterprise-installer-#{version}.pkg -target /"
          elsif host['platform'] =~ /eos/
            host.install_from_file("puppet-enterprise-#{version}-#{host['platform']}.swix")
          else
            pe_debug = host[:pe_debug] || opts[:pe_debug]  ? ' -D' : ''
            pe_cmd = "cd #{host['working_dir']}/#{host['dist']} && ./#{host['pe_installer']}#{pe_debug}"
            if ! version_is_less(host['pe_ver'], '2016.2.1') && ! opts[:interactive]
              # -y option sets "assume yes" mode where yes or whatever default will be assumed
              pe_cmd += " -y"
            end

            # If we are doing an upgrade from 2016.2.0,
            # we can assume there will be a valid pe.conf in /etc that we can re-use.
            # We also expect that any custom_answers specified to beaker have been
            # added to the pe.conf in /etc.
            if opts[:type] == :upgrade && use_meep?(host[:previous_pe_ver])
              "#{pe_cmd}"
            else
              "#{pe_cmd} #{host['pe_installer_conf_setting']}"
            end
          end
        end

        #This calls the installer command on the host in question
        def execute_installer_cmd(host, opts)
          on host, installer_cmd(host, opts)
        end

        #Determine the PE package to download/upload on a mac host, download/upload that package onto the host.
        # Assumed file name format: puppet-enterprise-3.3.0-rc1-559-g97f0833-osx-10.9-x86_64.dmg.
        # @param [Host] host The mac host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_mac(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          filename = "#{host['dist']}"
          extension = ".dmg"
          if local
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
          else
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            if opts[:fetch_local_then_push_to_host]
              fetch_and_push_pe(host, path, filename, extension)
            else
              curlopts = opts[:use_proxy] ? " --proxy #{opts[:proxy_hostname]}:3128" : ""
              on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}#{curlopts}"
            end
          end
        end

        #Determine the PE package to download/upload on a windows host, download/upload that package onto the host.
        #Assumed file name format: puppet-enterprise-3.3.0-rc1-559-g97f0833.msi
        # @param [Host] host The windows host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_windows(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          filename = "#{host['dist']}"
          extension = ".msi"
          if local
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
          else
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            if opts[:fetch_local_then_push_to_host]
              fetch_and_push_pe(host, path, filename, extension)
              on host, "cd #{host['working_dir']}; chmod 644 #{filename}#{extension}"
            elsif host.is_cygwin?
              curlopts = opts[:use_proxy] ? " --proxy #{opts[:proxy_hostname]}:3128" : ""
              on host, "cd #{host['working_dir']}; curl -O #{path}/#{filename}#{extension}#{curlopts}"
            else
              on host, powershell("$webclient = New-Object System.Net.WebClient;  $webclient.DownloadFile('#{path}/#{filename}#{extension}','#{host['working_dir']}\\#{filename}#{extension}')")
            end
          end
        end

        #Determine the PE package to download/upload on a unix style host, download/upload that package onto the host
        #and unpack it.
        # @param [Host] host The unix style host to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe_on_unix(host, opts)
          path = host['pe_dir'] || opts[:pe_dir]
          local = File.directory?(path)
          filename = "#{host['dist']}"
          if local
            extension = File.exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            if not File.exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end
            scp_to host, "#{path}/#{filename}#{extension}", "#{host['working_dir']}/#{filename}#{extension}"
            if extension =~ /gz/
              on host, "cd #{host['working_dir']}; gunzip #{filename}#{extension}"
            end
            if extension =~ /tar/
              on host, "cd #{host['working_dir']}; tar -xvf #{filename}.tar"
            end
          else
            if host['platform'] =~ /eos/
              extension = '.swix'
            else
              extension = link_exists?("#{path}/#{filename}.tar.gz") ? ".tar.gz" : ".tar"
            end
            if not link_exists?("#{path}/#{filename}#{extension}")
              raise "attempting installation on #{host}, #{path}/#{filename}#{extension} does not exist"
            end

            if host['platform'] =~ /eos/
              host.get_remote_file("#{path}/#{filename}#{extension}")
            else
              unpack = 'tar -xvf -'
              unpack = extension =~ /gz/ ? 'gunzip | ' + unpack  : unpack
              if opts[:fetch_local_then_push_to_host]
                fetch_and_push_pe(host, path, filename, extension)
                command_file_push = 'cat '
              else
                curlopts = opts[:use_proxy] ? "--proxy #{opts[:proxy_hostname]}:3128 " : ""
                command_file_push = "curl #{curlopts}#{path}/"
              end
              on host, "cd #{host['working_dir']}; #{command_file_push}#{filename}#{extension} | #{unpack}"

            end
          end
        end

        #Determine the PE package to download/upload per-host, download/upload that package onto the host
        #and unpack it.
        # @param [Array<Host>] hosts The hosts to download/upload and unpack PE onto
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
        #                  (Otherwise uses individual Windows hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @api private
        def fetch_pe(hosts, opts)
          hosts.each do |host|
            # We install Puppet from the master for frictionless installs, so we don't need to *fetch* anything
            next if host['roles'].include?('frictionless') && (! version_is_less(opts[:pe_ver] || host['pe_ver'], '3.2.0'))

            if host['platform'] =~ /windows/
              fetch_pe_on_windows(host, opts)
            elsif host['platform'] =~ /osx/
              fetch_pe_on_mac(host, opts)
            else
              fetch_pe_on_unix(host, opts)
            end
          end
        end

        #Classify the master so that it can deploy frictionless packages for a given host.
        #This function does nothing when using meep for classification.
        # @param [Host] host The host to install pacakges for
        # @api private
        def deploy_frictionless_to_master(host)
          return if use_meep_for_classification?(master[:pe_ver], options)

          # For some platforms (e.g, redhatfips), packaging_platfrom is set and should
          # be used as the primary source of truth for the platform string.
          platform = host['packaging_platform'] || host['platform']

          # We don't have a separate AIX 7.2 build, so it is
          # classified as 7.1 for pe_repo purposes
          if platform == "aix-7.2-power"
            platform = "aix-7.1-power"
          end
          klass = platform.gsub(/-/, '_').gsub(/\./,'')
          if host['platform'] =~ /windows/
            if host['template'] =~ /i386/
              klass = "pe_repo::platform::windows_i386"
            else
              klass = "pe_repo::platform::windows_x86_64"
            end
          else
            klass = "pe_repo::platform::#{klass}"
          end
          if version_is_less(host['pe_ver'], '3.8')
            # use the old rake tasks
            on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake nodeclass:add[#{klass},skip]"
            on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake node:add[#{master},,,skip]"
            on dashboard, "cd /opt/puppet/share/puppet-dashboard && /opt/puppet/bin/bundle exec /opt/puppet/bin/rake node:addclass[#{master},#{klass}]"
            on master, puppet("agent -t"), :acceptable_exit_codes => [0,2]
          else
            _console_dispatcher = get_console_dispatcher_for_beaker_pe!

            # Add pe_repo packages to 'PE Master' group
            node_group = _console_dispatcher.get_node_group_by_name('PE Master')

            # add the pe_repo platform class if it's not already present
            if node_group
              if !node_group['classes'].include?(klass)
                node_group['classes'][klass] = {}
                _console_dispatcher.create_new_node_group_model(node_group)

                # The puppet agent run that will download the agent tarballs to the master can sometimes fail with
                # curl errors if there is a network hiccup. Use beakers `retry_on` method to retry up to
                # three times to avoid failing the entire test pipeline due to a network blip
                retry_opts = {
                  :desired_exit_codes => [0,2],
                  :max_retries => 3,
                  # Beakers retry_on method wants the verbose value to be a string, not a bool.
                  :verbose => 'true'
                }
                retry_on(master, puppet("agent -t"), retry_opts)

                # If we are connecting through loadbalancer, download the agent tarballs to compile masters
                if lb_connect_loadbalancer_exists?
                  hosts.each do |h|
                    if h['roles'].include?('compile_master') || h['roles'].include?('pe_compiler')
                      retry_on(h, puppet("agent -t"), retry_opts)
                    end
                  end
                end
              end
            else
              raise "Failed to add pe_repo packages, PE Master node group is not available"
            end
          end
        end

        # Check for availability of required network resources
        # @param [Array<Host>] hosts
        # @param [Array<String>] network_resources
        #
        # @example
        #   verify_network_resources(hosts, network_resources)
        #
        # @return nil
        #
        # @api private
        def verify_network_resources(hosts, network_resources)
          logger.notify("Checking the availability of network resources.")
          hosts.each do |host|
            # if options[:net_diag_hosts] isn't set, skip this check
            if network_resources != nil
              network_resources.each do |resource|
                # curl the network resource silently (-s), only connect (-I), and don't print the output
                on host, "curl -I -s #{resource} > /dev/null", :accept_all_exit_codes => true
                if host.connection.logger.last_result.exit_code != 0
                  logger.warn("Connection error: #{host.host_hash[:vmhostname]} was unable to connect to #{resource}. Please ensure that your test does not require this resource.")
                end
              end
            end
            hosts.each do |target_host|
              ping_opts = host['platform'] =~ /windows/ ? "-n 1" : "-c1"
              on host, "ping #{ping_opts} #{target_host.host_hash[:vmhostname]} > /dev/null", :accept_all_exit_codes => true
              if host.connection.logger.last_result.exit_code != 0
                logger.warn("Connection error: #{host.host_hash[:vmhostname]} was unable to connect to #{target_host.host_hash[:vmhostname]} in your testing infrastructure.")
              end
            end
          end
        end

        # Check system resources, so that we might be able to find correlations
        # between absurd load levels and transients.
        # @param [Array<Host>] hosts
        #
        # @example
        #   verify_vm_resources(hosts)
        #
        # @return nil
        #
        # @api private
        def verify_vm_resources(hosts)
          logger.notify("Checking the status of system (CPU/Mem) resources on PE Infrastructure nodes.")
          pe_infrastructure = select_hosts({:roles => ['master', 'compile_master', 'pe_compiler', 'dashboard', 'database']}, hosts)
          pe_infrastructure.each do |host|
            on host, "top -bn1", :accept_all_exit_codes => true
            on host, "vmstat 1 1", :accept_all_exit_codes => true
          end
        end

        #Perform a Puppet Enterprise upgrade or install
        # @param [Array<Host>] hosts The hosts to install or upgrade PE on
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install or upgrade to
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [String] :pe_ver_win Default PE version to install or upgrade to on Windows hosts
        #                  (Otherwise uses individual Windows hosts pe_ver)
        # @option opts [Symbol] :type (:install) One of :upgrade or :install
        # @option opts [Boolean] :set_console_password Should we set the PE console password in the answers file?  Used during upgrade only.
        # @option opts [Hash<String>] :answers Pre-set answers based upon ENV vars and defaults
        #                             (See {Beaker::Options::Presets.env_vars})
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @option opts [Boolean] :masterless Are we performing a masterless installation?
        #
        # @example
        #  do_install(hosts, {:type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win =>  version_win})
        #
        # @note on windows, the +:ruby_arch+ host parameter can determine in addition
        # to other settings whether the 32 or 64bit install is used
        #
        # @note for puppet-agent install options, refer to
        #   {Beaker::DSL::InstallUtils::FOSSUtils#install_puppet_agent_pe_promoted_repo_on}
        #
        # @api private
        #
        def do_install hosts, opts = {}
          # detect the kind of install we're doing
          install_type = determine_install_type(hosts, opts)
          verify_network_resources(hosts, options[:net_diag_hosts])
          verify_vm_resources(hosts)
          if opts[:use_proxy]
            config_hosts_for_proxy_access(hosts - hosts_as('proxy'))
          end
          case install_type
          when :pe_managed_postgres
            do_install_pe_with_pe_managed_external_postgres(hosts,opts)
          when :simple_monolithic
            simple_monolithic_install(hosts.first, hosts.drop(1), opts)
          when :simple_split
            # This isn't implemented yet, so just do a generic install instead
            #simple_split_install(hosts, opts)
            generic_install(hosts, opts)
          else
            generic_install(hosts, opts)
          end
        end

        def has_all_roles?(host, roles)
          roles.all? {|role| host['roles'].include?(role)}
        end

        # Determine what kind of install is being performed
        # @param [Array<Host>] hosts The sorted hosts to install or upgrade PE on
        # @param [Hash{Symbol=>Symbol, String}] opts The options for how to install or upgrade PE
        #
        # @example
        #   determine_install_type(hosts, {:type => :install, :pe_ver => '2017.2.0'})
        #
        # @return [Symbol]
        #   One of :generic, :simple_monolithic, :simple_split, :pe_managed_postgres
        #   :simple_monolithic
        #     returned when installing >=2016.4 with a monolithic master and
        #     any number of frictionless agents
        #   :simple_split
        #     returned when installing >=2016.4 with a split install and any
        #     number of frictionless agents
        #   :pe_managed_postgres
        #     returned when installing PE with postgres being managed on a node
        #     that is different then the database node
        #   :generic
        #     returned for any other install or upgrade
        #
        # @api private
        def determine_install_type(hosts, opts)
          # Do a generic install if this is masterless, not all the same PE version, an upgrade, or earlier than 2016.4
          return :generic if opts[:masterless]
          return :generic if hosts.map {|host| host['pe_ver']}.uniq.length > 1
          return :generic if (opts[:type] == :upgrade) && (hosts.none? {|host| host['roles'].include?('pe_postgres')})
          return :generic if version_is_less(opts[:pe_ver] || hosts.first['pe_ver'], '2016.4')
          #PE-20610 Do a generic install for old versions on windows that needs msi install because of PE-18351
          return :generic if hosts.any? {|host| host['platform'] =~ /windows/ && install_via_msi?(host)}

          mono_roles = ['master', 'database', 'dashboard']
          if has_all_roles?(hosts.first, mono_roles) && hosts.drop(1).all? {|host| host['roles'].include?('frictionless')}
            :simple_monolithic
          elsif hosts[0]['roles'].include?('master') && hosts[1]['roles'].include?('database') && hosts[2]['roles'].include?('dashboard') && hosts.drop(3).all? {|host| host['roles'].include?('frictionless')}
            :simple_split
          elsif hosts.any? {|host| host['roles'].include?('pe_postgres')}
            :pe_managed_postgres
          else
            :generic
          end
        end

        # Install PE on a monolithic master and some number of frictionless agents.
        # @param [Host] master The node to install the master on
        # @param [Array<Host>] agents The nodes to install agents on
        # @param [Hash{Symbol=>Symbol, String}] opts The options for how to install or upgrade PE
        #
        # @example
        #   simple_monolithic_install(master, agents, {:type => :install, :pe_ver => '2017.2.0'})
        #
        # @return nil
        #
        # @api private
        def simple_monolithic_install(master, agents, opts={})
          step "Performing a standard monolithic install with frictionless agents"
          all_hosts = [master, *agents]
          configure_type_defaults_on([master])

          # Set PE distribution on the agents, creates working directories
          prepare_hosts(all_hosts, opts)
          fetch_pe([master], opts)
          prepare_host_installer_options(master)
          register_feature_flags!(opts)
          generate_installer_conf_file_for(master, all_hosts, opts)
          step "Install PE on master" do
            on master, installer_cmd(master, opts)
          end

          step "Stop agent on master" do
            stop_agent_on(master)
          end

          if manage_puppet_service?(master[:pe_ver], options)
            configure_puppet_agent_service(:ensure => 'stopped', :enabled => false)
          end

          step "Run puppet to setup mcollective and pxp-agent" do
            on(master, puppet_agent('-t'), :acceptable_exit_codes => [0,2])
          end

          install_agents_only_on(agents, opts)

          step "Run puppet a second time on the primary to populate services.conf (PE-19054)" do
            on(master, puppet_agent('-t'), :acceptable_exit_codes => [0,2])
          end
        end


        # Configure the master to use a proxy and drop unproxied connections
        def config_hosts_for_proxy_access hosts
          hosts.each do |host|
            step "Configuring #{host} to use proxy" do
              @osmirror_host = "osmirror.delivery.puppetlabs.net"
              @osmirror_host_ip = IPSocket.getaddress(@osmirror_host)
              @delivery_host = "artifactory.delivery.puppetlabs.net"
              @delivery_host_ip = IPSocket.getaddress(@delivery_host)
              @test_forge_host = "api-forge-aio02-petest.puppet.com"
              @test_forge_host_ip = IPSocket.getaddress(@test_forge_host)
              @github_host = "github.com"
              @github_host_ip = IPSocket.getaddress(@github_host)
              @proxy_ip = @options[:proxy_ip]
              @proxy_hostname = @options[:proxy_hostname]

              #sles does not support the -I all-ip-addresses flag
              hostname_flag = host.host_hash[:platform].include?("sles") ? '-i' : '-I'
              @master_ip = on master, "hostname #{hostname_flag} | tr '\n' ' '"

              on host, "echo \"#{@proxy_ip}  #{@proxy_hostname}\" >> /etc/hosts"
              on host, "echo \"#{@master_ip.stdout}  #{master.connection.vmhostname}\" >> /etc/hosts"
              on host, "echo \"#{@osmirror_host_ip}    #{@osmirror_host}\" >> /etc/hosts"
              on host, "echo \"#{@delivery_host_ip}    #{@delivery_host}\" >> /etc/hosts"
              on host, "echo \"#{@test_forge_host_ip}    #{@test_forge_host}\" >> /etc/hosts"
              on host, "echo \"#{@github_host_ip}    #{@github_host}\" >> /etc/hosts"

              on host, "iptables -A OUTPUT -p tcp -d #{master.connection.vmhostname} -j ACCEPT"
              # Treat these hosts as if they were outside the puppet lan
              on host, "iptables -A OUTPUT -p tcp -d #{@osmirror_host_ip} -j DROP"
              on host, "iptables -A OUTPUT -p tcp -d #{@delivery_host_ip} -j DROP"
              on host, "iptables -A OUTPUT -p tcp -d #{@test_forge_host_ip} -j DROP"
              # The next two lines clear the rest of the internal puppet lan
              on host, "iptables -A OUTPUT -p tcp -d 10.16.0.0/16 -j ACCEPT"
              on host, "iptables -A OUTPUT -p tcp -d 10.32.0.0/16 -j ACCEPT"
              # This allows udp on a port bundler requires
              on host, 'iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT'
              # Next two lines allow host to access itself via localhost or 127.0.0.1
              on host, 'iptables -A INPUT -i lo -j ACCEPT'
              on host, 'iptables -A OUTPUT -o lo -j ACCEPT'
              #Opens up port that git uses
              on host, "iptables -A OUTPUT -p tcp -d #{@github_host_ip} -j ACCEPT"
              on host, "iptables -A INPUT -p tcp -d #{@github_host_ip} --dport 9143 -j ACCEPT"

              #Platform9
              on host, "iptables -A OUTPUT -p tcp -d 10.234.0.0/16 -j ACCEPT"
              #enterprise.delivery.puppetlabs.net network, required if running from your work laptop over the network
              on host, "iptables -A OUTPUT -p tcp -d 10.0.25.0/16 -j ACCEPT"

              on host, "iptables -A OUTPUT -p tcp --dport 3128 -d #{@proxy_hostname} -j ACCEPT"
              on host, "iptables -P OUTPUT DROP"
              # Verify we can reach osmirror via the proxy
              on host, "curl --proxy #{@proxy_hostname}:3128 http://#{@osmirror_host}", :acceptable_exit_codes => [0]
              # Verify we can't reach it without the proxy
              on host, "curl -k http://#{@osmirror_host} -m 5", :acceptable_exit_codes => [28]
              # For ubuntu we configure Apt to use a proxy globally
              if host.host_hash[:platform].include?("ubuntu")
                on host, "echo 'Acquire::http::Proxy \"http://'#{@proxy_hostname}':3128/\";' >> /etc/apt/apt.conf"
                on host, "echo 'Acquire::https::Proxy \"http://'#{@proxy_hostname}':3128/\";' >> /etc/apt/apt.conf"
              # For SLES we configure ENV variables to use a proxy, then set no_proxy on master and possible CM
              elsif host.host_hash[:platform].include?("sles")
                on host, 'rm /etc/sysconfig/proxy'
                on host, 'echo "PROXY_ENABLED=\"yes\"" >> /etc/sysconfig/proxy'
                on host, "echo 'HTTP_PROXY=\"http://#{@proxy_hostname}:3128\"' >> /etc/sysconfig/proxy"
                on host, "echo 'HTTPS_PROXY=\"http://#{@proxy_hostname}:3128\"' >> /etc/sysconfig/proxy"
                #Needs to not use proxy on the host itself, and master (in order to download the agent)
                no_proxy_list="localhost,127.0.0.1,#{host.hostname},#{master.hostname}"
                if any_hosts_as?('compile_master')
                  no_proxy_list.concat(",#{compile_master}")
                end
                on host, "echo \"NO_PROXY='#{no_proxy_list}'\" >> /etc/sysconfig/proxy"
              # For Redhat/Centos we configre Yum globally to use a proxy
              else
                on host, "echo 'proxy=http://#{@proxy_hostname}:3128' >> /etc/yum.conf"
              end
            end
          end
        end


        def generic_install hosts, opts = {}
          step "Installing PE on a generic set of hosts"

          masterless = opts[:masterless]
          opts[:type] = opts[:type] || :install
          unless masterless
            pre30database = version_is_less(opts[:pe_ver] || database['pe_ver'], '3.0')
            pre30master = version_is_less(opts[:pe_ver] || master['pe_ver'], '3.0')
          end

          pe_versions = ( [] << opts['pe_ver'] << hosts.map{ |host| host['pe_ver'] } ).flatten.compact
          agent_only_check_needed = version_is_less('3.99', max_version(pe_versions, '3.8'))
          if agent_only_check_needed
            hosts_agent_only, hosts_not_agent_only = create_agent_specified_arrays(hosts)
          else
            hosts_agent_only, hosts_not_agent_only = [], hosts.dup
          end

          # On January 5th, 2017, the extended GPG key has expired. Rather then
          # every few months updating this gem to point to a new key for PE versions
          # less then PE 2016.4.0 we are going to just ignore the warning when installing
          ignore_gpg_key_warning_on_hosts(hosts, opts)

          # Set PE distribution for all the hosts, create working dir
          prepare_hosts(hosts_not_agent_only, opts)

          fetch_pe(hosts_not_agent_only, opts)

          install_hosts = hosts.dup
          unless masterless
            # If we're installing a database version less than 3.0, ignore the database host
            install_hosts.delete(database) if pre30database and database != master and database != dashboard
          end

          install_hosts.each do |host|

            if agent_only_check_needed && hosts_agent_only.include?(host) || install_via_msi?(host)
              host['type'] = 'aio'
              install_params = {
                :puppet_agent_version => get_puppet_agent_version(host, opts),
                :puppet_agent_sha => host[:puppet_agent_sha] || opts[:puppet_agent_sha],
                :pe_ver => host[:pe_ver] || opts[:pe_ver],
                :puppet_collection => host[:puppet_collection] || opts[:puppet_collection],
                :pe_promoted_builds_url => host[:pe_promoted_builds_url] || opts[:pe_promoted_builds_url]
              }
              install_params.delete(:pe_promoted_builds_url) if install_params[:pe_promoted_builds_url].nil?
              install_puppet_agent_pe_promoted_repo_on(host, install_params)
              # 1 since no certificate found and waitforcert disabled
              acceptable_exit_codes = [0, 1]
              acceptable_exit_codes << 2 if opts[:type] == :upgrade
              if masterless
                configure_type_defaults_on(host)
                on host, puppet_agent('-t'), :acceptable_exit_codes => acceptable_exit_codes
              else
                setup_defaults_and_config_helper_on(host, master, acceptable_exit_codes)
              end
            #Windows allows frictionless installs starting with PE Davis, if frictionless we need to skip this step
            elsif (host['platform'] =~ /windows/ && !(host['roles'].include?('frictionless')) || install_via_msi?(host))
              opts = { :debug => host[:pe_debug] || opts[:pe_debug] }
              msi_path = "#{host['working_dir']}\\#{host['dist']}.msi"
              install_msi_on(host, msi_path, {}, opts)

              # 1 since no certificate found and waitforcert disabled
              acceptable_exit_codes = 1
              if masterless
                configure_type_defaults_on(host)
                on host, puppet_agent('-t'), :acceptable_exit_codes => acceptable_exit_codes
              else
                setup_defaults_and_config_helper_on(host, master, acceptable_exit_codes)
              end
            else
              # We only need answers if we're using the classic installer
              version = host['pe_ver'] || opts[:pe_ver]
              if host['roles'].include?('frictionless') &&  (! version_is_less(version, '3.2.0'))
                # If We're *not* running the classic installer, we want
                # to make sure the master has packages for us.
                if host['packaging_platform'] != master['packaging_platform'] # only need to do this if platform differs
                  deploy_frictionless_to_master(host)
                end
                install_ca_cert_on(host, opts)
                on host, installer_cmd(host, opts)
                configure_type_defaults_on(host)
              elsif host['platform'] =~ /osx|eos/
                # If we're not frictionless, we need to run the OSX special-case
                on host, installer_cmd(host, opts)
                acceptable_codes = host['platform'] =~ /osx/ ? [1] : [0, 1]
                setup_defaults_and_config_helper_on(host, master, acceptable_codes)
              else
                prepare_host_installer_options(host)
                register_feature_flags!(opts)
                setup_pe_conf(host, hosts, opts)

                on host, installer_cmd(host, opts)
                configure_type_defaults_on(host)
                download_pe_conf_if_master(host)
              end
            end
            # On each agent, we ensure the certificate is signed
            if !masterless
              if [master, database, dashboard].include?(host) && use_meep?(host['pe_ver'])
                # This step is not necessary for the core pe nodes when using meep
              else
                step "Sign certificate for #{host}" do
                  sign_certificate_for(host)
                end
              end
            end
            # then shut down the agent
            step "Shutting down agent for #{host}" do
              stop_agent_on(host)
            end
          end

          unless masterless
            # Wait for PuppetDB to be totally up and running (post 3.0 version of pe only)
            sleep_until_puppetdb_started(database) unless pre30database

            step "First puppet agent run" do
              # Run the agent once to ensure everything is in the dashboard
              install_hosts.each do |host|
                on host, puppet_agent('-t'), :acceptable_exit_codes => [0,2]

                # Workaround for PE-1105 when deploying 3.0.0
                # The installer did not respect our database host answers in 3.0.0,
                # and would cause puppetdb to be bounced by the agent run. By sleeping
                # again here, we ensure that if that bounce happens during an upgrade
                # test we won't fail early in the install process.
                if host == database && ! pre30database
                  sleep_until_puppetdb_started(database)
                  check_puppetdb_status_endpoint(database)
                end
                if host == dashboard
                  check_console_status_endpoint(host)
                end
                #Workaround for windows frictionless install, see BKR-943 for the reason
                if (host['platform'] =~ /windows/) and (host['roles'].include? 'frictionless')
                  remove_client_datadir(host)
                end
              end
            end

            # only appropriate for pre-3.9 builds
            if version_is_less(master[:pe_ver], '3.99')
              if pre30master
                task = 'nodegroup:add_all_nodes group=default'
              else
                task = 'defaultgroup:ensure_default_group'
              end
              on dashboard, "/opt/puppet/bin/rake -sf /opt/puppet/share/puppet-dashboard/Rakefile #{task} RAILS_ENV=production"
            end

            if manage_puppet_service?(master[:pe_ver], options)
              configure_puppet_agent_service(:ensure => 'stopped', :enabled => false)
            end

            step "Final puppet agent run" do
              # Now that all hosts are in the dashbaord, run puppet one more
              # time to configure mcollective
              install_hosts.each do |host|
                on host, puppet_agent('-t'), :acceptable_exit_codes => [0,2]
                # To work around PE-14318 if we just ran puppet agent on the
                # database node we will need to wait until puppetdb is up and
                # running before continuing
                if host == database && ! pre30database
                  sleep_until_puppetdb_started(database)
                  check_puppetdb_status_endpoint(database)
                end
                if host == dashboard
                  check_console_status_endpoint(host)
                end
              end
            end
          end
        end

        # Prepares hosts for rest of {#do_install} operations.
        # This includes doing these tasks:
        # - setting 'pe_installer' property on hosts
        # - setting 'dist' property on hosts
        # - creating and setting 'working_dir' property on hosts
        #
        # @note that these steps aren't necessary for all hosts. Specifically,
        #   'agent_only' hosts do not require these steps to be executed.
        #
        # @param [Array<Host>] hosts Hosts to prepare
        # @param [Hash{Symbol=>String}] local_options Local options, used to
        #   pass misc configuration required for the prep steps
        #
        # @return nil
        def prepare_hosts(hosts, local_options={})
          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          hosts.each do |host|
            host['pe_installer'] ||= 'puppet-enterprise-installer'
            if host['platform'] !~ /windows|osx/
              platform = use_all_tar ? 'all' : host['platform']
              version = host['pe_ver'] || local_options[:pe_ver]
              host['dist'] = "puppet-enterprise-#{version}-#{platform}"
            elsif host['platform'] =~ /osx/
              version = host['pe_ver'] || local_options[:pe_ver]
              host['dist'] = "puppet-enterprise-#{version}-#{host['platform']}"
            elsif host['platform'] =~ /windows/
              version = host[:pe_ver] || local_options['pe_ver_win']
              is_config_32 = true == (host['ruby_arch'] == 'x86') || host['install_32'] || local_options['install_32']
              should_install_64bit = !(version_is_less(version, '3.4')) && host.is_x86_64? && !is_config_32
              #only install 64bit builds if
              # - we are on pe version 3.4+
              # - we do not have install_32 set on host
              # - we do not have install_32 set globally
              if !(version_is_less(version, '3.99'))
                if should_install_64bit
                  host['dist'] = "puppet-agent-#{version}-x64"
                else
                  host['dist'] = "puppet-agent-#{version}-x86"
                end
              elsif should_install_64bit
                host['dist'] = "puppet-enterprise-#{version}-x64"
              else
                host['dist'] = "puppet-enterprise-#{version}"
              end
            end
            host['dist'] = "puppet-enterprise-#{version}-#{host['packaging_platform']}" if host['packaging_platform'] =~ /redhatfips/
            host['working_dir'] = host.tmpdir(Time.new.strftime("%Y-%m-%d_%H.%M.%S"))
          end
        end

        # Gets the puppet-agent version, hopefully from the host or local options.
        # Will fall back to reading the `aio_agent_version` property on the master
        # if neither of those two options are passed
        #
        # @note This method does have a side-effect: if it reads the
        #   `aio_agent_version` property from master, it will store it in the local
        #   options hash so that it won't have to do this more than once.
        #
        # @param [Beaker::Host] host Host to get puppet-agent for
        # @param [Hash{Symbol=>String}] local_options local method options hash
        #
        # @return [String] puppet-agent version to install
        def get_puppet_agent_version(host, local_options={})
          puppet_agent_version = host[:puppet_agent_version] || local_options[:puppet_agent_version]
          return puppet_agent_version if puppet_agent_version
          log_prefix = "No :puppet_agent_version in host #{host} or local options."
          fail_message = "#{log_prefix} Could not read facts from master to determine puppet_agent_version"
          # we can query the master because do_install is called passing
          # the {#sorted_hosts}, so we know the master will be installed
          # before the agents
          facts_result = on(master, 'puppet facts')
          raise ArgumentError, fail_message if facts_result.exit_code != 0
          facts_hash = JSON.parse(facts_result.stdout.chomp)
          puppet_agent_version = facts_hash['values']['aio_agent_version']
          raise ArgumentError, fail_message if puppet_agent_version.nil?
          logger.warn("#{log_prefix} Read puppet-agent version #{puppet_agent_version} from master")
          # saving so that we don't have to query the master more than once
          local_options[:puppet_agent_version] = puppet_agent_version
          puppet_agent_version
        end

        # True if version is greater than or equal to MEEP_CUTOVER_VERSION (2016.2.0)
        def use_meep?(version)
          !version_is_less(version, MEEP_CUTOVER_VERSION)
        end

        # Tests if a feature flag has been set in the answers hash provided to beaker
        # options. Assumes a 'feature_flags' hash is present in the answers and looks for
        # +flag+ within it.
        #
        # @param flag String flag to lookup
        # @param opts Hash options hash to inspect
        # @return true if +flag+ is true or 'true' in the feature_flags hash,
        #   false otherwise. However, returns nil if there is no +flag+ in the
        #   answers hash at all
        def feature_flag?(flag, opts)
          Beaker::DSL::InstallUtils::FeatureFlags.new(opts).flag?(flag)
        end

        # @deprecated the !version_is_less(host['pe_ver'], '3.99') can be removed once we no longer support pre 2015.2.0 PE versions
        # Check if windows host is able to frictionlessly install puppet
        # @param [Beaker::Host] host that we are checking if it is possible to install frictionlessly to
        # @return [Boolean] true if frictionless is supported and not affected by known bugs
        def install_via_msi?(host)
          #windows agents from 4.0 -> 2016.1.2 were only installable via the aio method
          #powershell2 bug was fixed in PE 2016.4.3, and PE 2017.1.0, but not 2016.5.z.
          (host['platform'] =~ /windows/ && (version_is_less(host['pe_ver'], '2016.4.0') && !version_is_less(host['pe_ver'], '3.99'))) ||
            (host['platform'] =~ /windows-2008r2/ && (version_is_less(host['pe_ver'], '2016.4.3') && !version_is_less(host['pe_ver'], '3.99'))) ||
            (host['platform'] =~ /windows-2008r2/ && (!version_is_less(host['pe_ver'], '2016.4.99') && version_is_less(host['pe_ver'], '2016.5.99') && !version_is_less(host['pe_ver'], '3.99')))
        end

        # Runs puppet on all nodes, unless they have the roles: master,database,console/dashboard
        # @param [Array<Host>] hosts The sorted hosts to install or upgrade PE on
        def run_puppet_on_non_infrastructure_nodes(all_hosts)
          pe_infrastructure = select_hosts({:roles => ['master', 'compile_master', 'pe_compiler', 'dashboard', 'database']}, all_hosts)
          non_infrastructure = all_hosts.reject{|host| pe_infrastructure.include? host}
          on non_infrastructure, puppet_agent('-t'), :acceptable_exit_codes => [0,2], :run_in_parallel => true
        end

        # Whether or not PE should be managing the puppet service on agents.
        # Puppet code to manage the puppet service was added to the next branches
        # and is slated to be merged into 2018.1.x
        #
        # Returns true if the version we are managing is greater than or equal to
        # MANAGE_PUPPET_SERVICE_VERSION.
        #
        # Temporarily, (until merged from 'next' branches into 2018.1.x), also checks
        # the pe_modules_next flag to know whether or not the code for managing puppet
        # service is present.
        def manage_puppet_service?(version, opts)
          # PE-23651 remove vv
          register_feature_flags!(opts)

          temporary_flag = !!feature_flag?('pe_modules_next', opts)
          # ^^

          !version_is_less(version, MANAGE_PUPPET_SERVICE_VERSION) && temporary_flag
        end

        # True if version is greater than or equal to MEEP_CLASSIFICATION_VERSION
        # (PE-18718) AND the temporary feature flag is true.
        #
        # The temporary feature flag is meep_classification and can be set in
        # the :answers hash given in beaker's host.cfg, inside a feature_flags
        # hash. It will also be picked up from the environment as
        # MEEP_CLASSIFICATION. (See register_feature_flags!())
        #
        # The :answers hash value will take precedence over the env variable.
        #
        # @param version String the current PE version
        # @param opts Hash options hash to inspect for :answers
        # @return Boolean true if version and flag allows for meep classification
        #   feature.
        def use_meep_for_classification?(version, opts)
          # PE-19470 remove vv
          register_feature_flags!(opts)

          temporary_flag = feature_flag?('meep_classification', opts)
          temporary_flag = DEFAULT_MEEP_CLASSIFICATION if temporary_flag.nil?
          # ^^

          !version_is_less(version, MEEP_CLASSIFICATION_VERSION) && temporary_flag
        end

        # For PE 3.8.5 to PE 2016.1.2 they have an expired gpg key. This method is
        # for deb nodes to ignore the gpg-key expiration warning
        def ignore_gpg_key_warning_on_hosts(hosts, opts)
          hosts.each do |host|
            # RPM based platforms do not seem to be effected by an expired GPG key,
            # while deb based platforms are failing.
            if host['platform'] =~ /debian|ubuntu/
              host_ver = host['pe_ver'] || opts['pe_ver']

              if version_is_less(host_ver, '3.8.7') || (!version_is_less(host_ver, '2015.2.0') && version_is_less(host_ver, '2016.4.0'))
                on(host, "echo 'APT { Get { AllowUnauthenticated \"1\"; }; };' >> /etc/apt/apt.conf")
              end
            end
          end
        end

        # Set installer options on the passed *host* according to current
        # version.
        #
        # Sets:
        #   * 'pe_installer_conf_file'
        #   * 'pe_installer_conf_setting'
        #
        # @param [Beaker::Host] host The host object to configure
        # @return [Beaker::Host] The same host object passed in
        def prepare_host_installer_options(host)
          if use_meep?(host['pe_ver'])
            conf_file = "#{host['working_dir']}/pe.conf"
            host['pe_installer_conf_file'] = conf_file
            host['pe_installer_conf_setting'] = "-c #{conf_file}"
          else
            conf_file = "#{host['working_dir']}/answers"
            host['pe_installer_conf_file'] = conf_file
            host['pe_installer_conf_setting'] = "-a #{conf_file}"
          end
          host
        end

        # Adds in settings needed by BeakerAnswers:
        #
        # * :format => :bash or :hiera depending on which legacy or meep format we need
        # * :include_legacy_database_defaults => true or false.  True
        #   indicates that we are upgrading from a legacy version and
        #   BeakerAnswers should include the database defaults for user
        #   which were set for the legacy install.
        #
        # @param [Beaker::Host] host that we are generating answers for
        # @param [Hash] opts The Beaker options hash
        # @return [Hash] a dup of the opts hash with additional settings for BeakerAnswers
        def setup_beaker_answers_opts(host, opts)
          beaker_answers_opts = use_meep?(host['pe_ver']) ?
            { :format => :hiera } :
            { :format => :bash }

          beaker_answers_opts[:include_legacy_database_defaults] =
            opts[:type] == :upgrade && !use_meep?(host['previous_pe_ver'])

          modified_opts = opts.merge(beaker_answers_opts)

          answers_hash = modified_opts[:answers] ||= {}
          if !answers_hash.include?(:meep_schema_version)
            if feature_flag?(:meep_classification, opts)
              answers_hash[:meep_schema_version] = '2.0'
            elsif use_meep?(host['pe_ver'])
              answers_hash[:meep_schema_version] = '1.0'
            end
          end

          modified_opts
        end

        # The pe-modules-next package is being used for isolating large scale
        # feature development of PE module code. The feature flag is a pe.conf
        # setting 'feature_flags::pe_modules_next', which if set true will
        # cause the installer shim to install the pe-modules-next package
        # instead of pe-modules.
        #
        # This answer can be explicitly added to Beaker's cfg file by adding it
        # to the :answers section.
        #
        # But it can also be picked up transparently from CI via the
        # PE_MODULES_NEXT environment variable.  If this is set 'true', then
        # the opts[:answers] will be set with feature_flags::pe_modules_next.
        #
        # Answers set in Beaker's config file will take precedence over the
        # environment variable.
        #
        # NOTE: This has implications for upgrades, because upgrade testing
        # will need the flag, but upgrades from different pe.conf schema (or no
        # pe.conf) will need to generate a pe.conf, and that workflow is likely
        # to happen in the installer shim.  If we simply supply a good pe.conf
        # via beaker-answers, then we have bypassed the pe.conf generation
        # aspect of the upgrade workflow. (See PE-19438)
        def register_feature_flags!(opts)
          Beaker::DSL::InstallUtils::FeatureFlags.new(opts).register_flags!
        end

        # PE 2018.1.0 has mco disabled by default. If we are running hosts with
        # roles hub or spoke then we intend to test mco. In this case we need
        # to change a setting in pe.conf to allow mco to be enabled.
        def get_mco_setting(hosts)
          pe_version = hosts[0]['pe_ver']
          if (!version_is_less(pe_version, '2018.1') && version_is_less(pe_version, '2018.1.999'))
                if (hosts.any? {|h| h['roles'].include?('hub') || h['roles'].include?('spoke')})
                  return {:answers => { 'pe_install::disable_mco' => false }}
                end
          end
          return {}
        end

        # Generates a Beaker Answers object for the passed *host* and creates
        # the answer or pe.conf configuration file on the *host* needed for
        # installation.
        #
        # Expects the host['pe_installer_conf_file'] to have been set, which is
        # where the configuration will be written to, and will run MEEP or legacy
        # depending on host[:pe_ver]
        #
        # @param [Beaker::Host] host The host to create a configuration file on
        # @param [Array<Beaker::Host]> hosts All of the hosts to be configured
        # @param [Hash] opts The Beaker options hash
        # @return [BeakerAnswers::Answers] the generated answers object
        def generate_installer_conf_file_for(host, hosts, opts)
          possible_mco_enabled_setting = get_mco_setting(hosts)
          opts ||= {}
          opts = possible_mco_enabled_setting.deep_merge(opts)
          beaker_answers_opts = setup_beaker_answers_opts(host, opts)
          answers = BeakerAnswers::Answers.create(
            opts[:pe_ver] || host['pe_ver'], hosts, beaker_answers_opts
          )
          configuration = answers.installer_configuration_string(host)

          step "Generate the #{host['pe_installer_conf_file']} on #{host}" do
            logger.debug(configuration)
            create_remote_file(host, host['pe_installer_conf_file'], configuration)
          end

          answers
        end

        # Builds the agent_only and not_agent_only arrays needed for installation.
        #
        # @param [Array<Host>]          hosts hosts to split up into the arrays
        #
        # @note should only be called against versions 4.0+, as this method
        #   assumes AIO packages will be required.
        #
        # @note agent_only hosts with the :pe_ver setting < 4.0 will not be
        #   included in the agent_only array, as AIO install can only happen
        #   in versions > 4.0
        #
        # @api private
        # @return [Array<Host>, Array<Host>]
        #   the array of hosts to do an agent_only install on and
        #   the array of hosts to do our usual install methods on
        def create_agent_specified_arrays(hosts)
          hosts_agent_only = []
          hosts_not_agent_only = []
          non_agent_only_roles = %w(master database dashboard console frictionless)
          hosts.each do |host|
            if host['roles'].none? {|role| non_agent_only_roles.include?(role) }
              if !aio_version?(host)
                hosts_not_agent_only << host
              else
                hosts_agent_only << host
              end
            else
              hosts_not_agent_only << host
            end
          end
          return hosts_agent_only, hosts_not_agent_only
        end

        # Helper for setting up pe_defaults & setting up the cert on the host
        # @param [Host] host                            host to setup
        # @param [Host] master                          the master host, for setting up the relationship
        # @param [Array<Fixnum>] acceptable_exit_codes  The exit codes that we want to ignore
        #
        # @return nil
        # @api private
        def setup_defaults_and_config_helper_on(host, master, acceptable_exit_codes=nil)
          configure_type_defaults_on(host)
          #set the certname and master
          on host, puppet("config set server #{master}")
          on host, puppet("config set certname #{host}")
          #run once to request cert
          on host, puppet_agent('-t'), :acceptable_exit_codes => acceptable_exit_codes
        end

        #Install PE based on global hosts with global options
        #@see #install_pe_on
        def install_pe
          install_pe_on(hosts, options)
        end

        def check_puppetdb_status_endpoint(host)
          if version_is_less(host['pe_ver'], '2016.1.0')
            return true
          end
          Timeout.timeout(60) do
            match = nil
            while not match
              output = on(host, "curl -s http://localhost:8080/pdb/meta/v1/version", :accept_all_exit_codes => true)
              match = output.stdout =~ /version.*\d+\.\d+\.\d+/
              sleep 1
            end
          end
        rescue Timeout::Error
          fail_test "PuppetDB took too long to start"
        end

        # Checks Console Status Endpoint, failing the test if the
        # endpoints don't report a running state.
        #
        # @param [Host] host Host to check status on
        #
        # @note Uses the global option's :pe_console_status_attempts
        #   value to determine how many times it's going to retry the
        #   check with fibonacci back offs.
        #
        # @return nil
        def check_console_status_endpoint(host)
          return true if version_is_less(host['pe_ver'], '2015.2.0')

          attempts_limit = options[:pe_console_status_attempts] || 9
          # Workaround for PE-14857. The classifier status service at the
          # default level is broken in 2016.1.1. Instead we need to query
          # the classifier service at critical level and check for service
          # status
          query_params = (host['pe_ver'] == '2016.1.1' ? '?level=critical' : '')
          step 'Check Console Status Endpoint' do
            match = repeat_fibonacci_style_for(attempts_limit) do
              output = on(host, "curl -s -k https://localhost:4433/status/v1/services#{query_params} --cert /etc/puppetlabs/puppet/ssl/certs/#{host}.pem --key /etc/puppetlabs/puppet/ssl/private_keys/#{host}.pem --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem", :accept_all_exit_codes => true)
              begin
                output = JSON.parse(output.stdout)
                match = output['classifier-service']['state'] == 'running'
                match = match && output['rbac-service']['state'] == 'running'
                match && output['activity-service']['state'] == 'running'
              rescue JSON::ParserError
                false
              end
            end
            fail_test 'Console services took too long to start' if !match
          end
        end

        #Install PE based upon host configuration and options
        #
        # @param [Host, Array<Host>] install_hosts    One or more hosts to act upon
        # @!macro common_opts
        # @option opts [Boolean] :masterless Are we performing a masterless installation?
        # @option opts [String] :puppet_agent_version  Version of puppet-agent to install. Required for PE agent
        #                                 only hosts on 4.0+
        # @option opts [String] :puppet_agent_sha The sha of puppet-agent to install, defaults to puppet_agent_version.
        #                                 Required for PE agent only hosts on 4.0+
        # @option opts [String] :pe_ver   The version of PE (will also use host['pe_ver']), defaults to '4.0'
        # @option opts [String] :puppet_collection   The puppet collection for puppet-agent install.
        #
        # @example
        #  install_pe_on(hosts, {})
        #
        # @note Either pe_ver and pe_dir should be set in the ENV or each host should have pe_ver and pe_dir set individually.
        #       Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
        #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
        #
        # @note For further installation parameters (such as puppet-agent install)
        #   options, refer to {#do_install} documentation
        #
        def install_pe_on(install_hosts, opts)
          confine_block(:to, {}, install_hosts) do
            sorted_hosts.each do |host|
              #process the version files if necessary
              host['pe_dir'] ||= opts[:pe_dir]
              if host['platform'] =~ /windows/
                # we don't need the pe_version if:
                # * master pe_ver > 4.0
                if not (!opts[:masterless] && master[:pe_ver] && !version_is_less(master[:pe_ver], '3.99'))
                  host['pe_ver'] ||= Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || opts[:pe_dir], opts[:pe_version_file_win])
                else
                  # inherit the master's version
                  host['pe_ver'] ||= master[:pe_ver]
                end
              else
                host['pe_ver'] ||= Beaker::Options::PEVersionScraper.load_pe_version(host[:pe_dir] || opts[:pe_dir], opts[:pe_version_file])
              end
            end
            do_install sorted_hosts, opts
          end
        end

        #Upgrade PE based upon global host configuration and global options
        #@see #upgrade_pe_on
        def upgrade_pe path=nil
          upgrade_pe_on(hosts, options, path)
        end

        #Upgrade PE based upon host configuration and options
        # @param [Host, Array<Host>]  upgrade_hosts   One or more hosts to act upon
        # @!macro common_opts
        # @param [String] path A path (either local directory or a URL to a listing of PE builds).
        #                      Will contain a LATEST file indicating the latest build to install.
        #                      This is ignored if a pe_upgrade_ver and pe_upgrade_dir are specified
        #                      in the host configuration file.
        # @example
        #  upgrade_pe_on(agents, {}, "http://neptune.puppetlabs.lan/3.0/ci-ready/")
        #
        # @note Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz)
        #       for Unix like systems and puppet-enterprise-VERSION.msi for Windows systems.
        def upgrade_pe_on upgrade_hosts, opts, path=nil
          confine_block(:to, {}, upgrade_hosts) do
            set_console_password = false
            # if we are upgrading from something lower than 3.4 then we need to set the pe console password
            if (dashboard[:pe_ver] ? version_is_less(dashboard[:pe_ver], "3.4.0") : true)
              set_console_password = true
            end
            # get new version information
            hosts.each do |host|
              prep_host_for_upgrade(host, opts, path)
            end

            do_install(sorted_hosts, opts.merge({:type => :upgrade, :set_console_password => set_console_password}))
            opts['upgrade'] = true
          end
        end

        #Prep a host object for upgrade; used inside upgrade_pe_on
        # @param [Host] host A single host object to prepare for upgrade
        # !macro common_opts
        # @param [String] path A path (either local directory or a URL to a listing of PE builds).
        #                      Will contain a LATEST file indicating the latest build to install.
        #                      This is ignored if a pe_upgrade_ver and pe_upgrade_dir are specified
        #                      in the host configuration file.
        # @example
        #  prep_host_for_upgrade(master, {}, "http://neptune.puppetlabs.lan/3.0/ci-ready/")
        def prep_host_for_upgrade(host, opts={}, path='')
          host['pe_dir'] = host['pe_upgrade_dir'] || path
          host['previous_pe_ver'] = host['pe_ver']
          if host['platform'] =~ /windows/
            host['pe_ver'] = host['pe_upgrade_ver'] || opts['pe_upgrade_ver'] ||
              Options::PEVersionScraper.load_pe_version(host['pe_dir'], opts[:pe_version_file_win])
          else
            host['pe_ver'] = host['pe_upgrade_ver'] || opts['pe_upgrade_ver'] ||
              Options::PEVersionScraper.load_pe_version(host['pe_dir'], opts[:pe_version_file])
          end
          if version_is_less(host['pe_ver'], '3.0')
            host['pe_installer'] ||= 'puppet-enterprise-upgrader'
          end
        end

        #Create the Higgs install command string based upon the host and options settings.  Installation command will be run as a
        #background process.  The output of the command will be stored in the provided host['higgs_file'].
        # @param [Host] host The host that Higgs is to be installed on
        #                    The host object must have the 'working_dir', 'dist' and 'pe_installer' field set correctly.
        # @api private
        def higgs_installer_cmd host
          higgs_answer = determine_higgs_answer(host['pe_ver'])
          "cd #{host['working_dir']}/#{host['dist']} ; nohup ./#{host['pe_installer']} <<<#{higgs_answer} > #{host['higgs_file']} 2>&1 &"
        end

        # Determines the answer to supply to the command line installer in order to load up Higgs
        # @return [String]
        #  One of, 'Y', '1', '2'
        #     'Y'
        #       Pre-meep install of Higgs (Before PE 2016.2.0)
        #     '1'
        #       meep before PE 2018.1.3 (PE 2016.2.0 -> PE 2018.1.2)
        #     '2'
        #       Any meep PE 2018.1.3 or greater
        def determine_higgs_answer(pe_ver)
          if(use_meep?(pe_ver))
            if(version_is_less(pe_ver, '2018.1.3'))
              return '1'
            elsif(version_is_less(pe_ver, '2019.0.2'))
              return '2'
            else
              return '3'
            end
          else
            return 'Y'
          end
        end

        #Perform a Puppet Enterprise Higgs install up until web browser interaction is required, runs on linux hosts only.
        # @param [Host] host The host to install higgs on
        # @param  [Hash{Symbol=>Symbol, String}] opts The options
        # @option opts [String] :pe_dir Default directory or URL to pull PE package from
        #                  (Otherwise uses individual hosts pe_dir)
        # @option opts [String] :pe_ver Default PE version to install
        #                  (Otherwise uses individual hosts pe_ver)
        # @option opts [Boolean] :fetch_local_then_push_to_host determines whether
        #                 you use Beaker as the middleman for this (true), or curl the
        #                 file from the host (false; default behavior)
        # @raise [StandardError] When installation times out
        #
        # @example
        #  do_higgs_install(master, {:pe_dir => path, :pe_ver => version})
        #
        # @api private
        #
        def do_higgs_install host, opts
          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          platform = use_all_tar ? 'all' : host['platform']
          version = host['pe_ver'] || opts[:pe_ver]
          host['dist'] = "puppet-enterprise-#{version}-#{platform}"

          use_all_tar = ENV['PE_USE_ALL_TAR'] == 'true'
          host['pe_installer'] ||= 'puppet-enterprise-installer'
          host['working_dir'] = host.tmpdir(Time.new.strftime("%Y-%m-%d_%H.%M.%S"))

          fetch_pe([host], opts)

          host['higgs_file'] = "higgs_#{File.basename(host['working_dir'])}.log"

          prepare_host_installer_options(host)
          on host, higgs_installer_cmd(host), opts

          #wait for output to host['higgs_file']
          #we're all done when we find this line in the PE installation log
          if version_is_less(opts[:pe_ver] || host['pe_ver'], '2016.3')
            higgs_re = /Please\s+go\s+to\s+https:\/\/.*\s+in\s+your\s+browser\s+to\s+continue\s+installation/m
          else
            higgs_re = /o\s+to\s+https:\/\/.*\s+in\s+your\s+browser\s+to\s+continue\s+installation/m
          end
          res = Result.new(host, 'tmp cmd')
          tries = 10
          attempts = 0
          prev_sleep = 0
          cur_sleep = 1
          while (res.stdout !~ higgs_re) and (attempts < tries)
            res = on host, "cd #{host['working_dir']}/#{host['dist']} && cat #{host['higgs_file']}", :accept_all_exit_codes => true
            attempts += 1
            sleep( cur_sleep )
            prev_sleep = cur_sleep
            cur_sleep = cur_sleep + prev_sleep
          end

          if attempts >= tries
            raise "Failed to kick off PE (Higgs) web installation"
          end
        end

        #Install Higgs up till the point where you need to continue installation in a web browser, defaults to execution
        #on the master node.
        #@param [Host] higgs_host The host to install Higgs on (supported on linux platform only)
        # @example
        #  install_higgs
        #
        # @note Either pe_ver and pe_dir should be set in the ENV or each host should have pe_ver and pe_dir set individually.
        #       Install file names are assumed to be of the format puppet-enterprise-VERSION-PLATFORM.(tar)|(tar.gz).
        #
        def install_higgs( higgs_host = master )
          #process the version files if necessary
          master['pe_dir'] ||= options[:pe_dir]
          master['pe_ver'] = master['pe_ver'] || options['pe_ver'] ||
            Beaker::Options::PEVersionScraper.load_pe_version(master[:pe_dir] || options[:pe_dir], options[:pe_version_file])
          if higgs_host['platform'] =~ /osx|windows/
            raise "Attempting higgs installation on host #{higgs_host.name} with unsupported platform #{higgs_host['platform']}"
          end
          #send in the global options hash
          do_higgs_install higgs_host, options
        end

        #Installs PE with a PE managed external postgres
        def do_install_pe_with_pe_managed_external_postgres(hosts, opts)
          pe_infrastructure = select_hosts({:roles => ['master', 'dashboard', 'database', 'pe_postgres']}, hosts)
          non_infrastructure = hosts.reject{|host| pe_infrastructure.include? host}

          is_upgrade = (original_pe_ver(hosts[0]) != hosts[0][:pe_ver])
          step "Setup tmp installer directory and pe.conf" do

            prepare_hosts(pe_infrastructure,opts)
            register_feature_flags!(opts)
            fetch_pe(pe_infrastructure,opts)

            [master, database, dashboard, pe_postgres].uniq.each do |host|
              configure_type_defaults_on(host)
              prepare_host_installer_options(host)

              unless is_upgrade
                setup_pe_conf(host, hosts, opts)
              end
            end
          end

          unless is_upgrade
            step "Initial master install, expected to fail due to RBAC database not being initialized" do
              begin
                execute_installer_cmd(master, opts)
              rescue Beaker::Host::CommandFailure => e
                unless is_expected_pe_postgres_failure?(master)
                  raise "Install on master failed in an unexpected manner"
                end
              end
            end
          end

          step "Install/Upgrade postgres service on pe-postgres node" do
            execute_installer_cmd(pe_postgres, opts)
          end

          step "Finish install/upgrade on infrastructure" do
              [master, database, dashboard].uniq.each do |host|
                execute_installer_cmd(host, opts)
              end
          end

          step "Stop agent service on infrastructure nodes" do
            stop_agent_on(pe_infrastructure, :run_in_parallel => true)
          end

          step "First puppet run on infrastructure + postgres node" do
            [master, database, dashboard, pe_postgres].uniq.each do |host|
              on host, 'puppet agent -t', :acceptable_exit_codes => [0,2]
            end
          end

          if(non_infrastructure.size > 0)
            install_agents_only_on(non_infrastructure, opts)

            step "Run puppet to setup mcollective and pxp-agent" do
              on master, 'puppet agent -t', :acceptable_exit_codes => [0,2]
              run_puppet_on_non_infrastructure_nodes(non_infrastructure)
            end

          end
          step "Run puppet a second time on the primary to populate services.conf (PE-19054)" do
            on master, 'puppet agent -t', :acceptable_exit_codes => [0,2]
          end
        end

        #Check the lastest install log to confirm the expected failure is there
        def is_expected_pe_postgres_failure?(host)
          installer_log_dir = '/var/log/puppetlabs/installer'
          latest_installer_log_file = on(host, "ls -1t #{installer_log_dir} | head -n1").stdout.chomp
          # As of PE Irving (PE 2018.1.x), these are the only two expected errors
          allowed_errors = ["The operation could not be completed because RBACs database has not been initialized",
            "Timeout waiting for the database pool to become ready",
            "Systemd restart for pe-console-services failed",
            "Execution of.*service pe-console-services.*: Reload timed out after 120 seconds"]

          allowed_errors.each do |error|
            if(on(host, "grep '#{error}' #{installer_log_dir}/#{latest_installer_log_file}", :acceptable_exit_codes => [0,1]).exit_code == 0)
              return true
            end
          end

          false
        end

        # Grabs the pe file from a remote host to the machine running Beaker, then
        # scp's the file out to the host.
        #
        # @param [Host] host The host to install on
        # @param [String] path path to the install file
        # @param [String] filename the filename of the pe file (without the extension)
        # @param [String] extension the extension of the pe file
        # @param [String] local_dir the directory to store the pe file in on
        #                   the Beaker-running-machine
        #
        # @api private
        # @return nil
        def fetch_and_push_pe(host, path, filename, extension, local_dir='tmp/pe')
          fetch_http_file("#{path}", "#{filename}#{extension}", local_dir)
          scp_to host, "#{local_dir}/#{filename}#{extension}", host['working_dir']
        end

        # Being able to modify PE's classifier requires the Scooter gem and
        # helpers which are in beaker-pe-large-environments.
        def get_console_dispatcher_for_beaker_pe(raise_exception = false)
          # XXX RE-8616, once scooter is public, we can remove this and just
          # reference ConsoleDispatcher directly.
          if !respond_to?(:get_dispatcher)
            begin
              require 'scooter'
              Scooter::HttpDispatchers::ConsoleDispatcher.new(dashboard)
            rescue LoadError => e
              logger.notify('WARNING: gem scooter is required for frictionless installation post 3.8')
              raise e if raise_exception

              return nil
            end
          else
            get_dispatcher
          end
        end

        # Will raise a LoadError if unable to require Scooter.
        def get_console_dispatcher_for_beaker_pe!
          get_console_dispatcher_for_beaker_pe(true)
        end

        # In PE versions >= 2018.1.0, allows you to configure the puppet agent
        # service for all nodes.
        #
        # @param parameters [Hash] - agent profile parameters
        # @option parameters [Boolean] :managed - whether or not to manage the
        #   agent resource at all (Optional, defaults to true).
        # @option parameters [String] :ensure - 'stopped', 'running'
        # @option parameters [Boolean] :enabled - whether the service will be
        #   enabled (for restarts)
        # @raise [StandardError] if master version is less than 2017.1.0
        def configure_puppet_agent_service(parameters)
          raise(StandardError, "Can only manage puppet service in PE versions >= #{MANAGE_PUPPET_SERVICE_VERSION}; tried for #{master['pe_ver']}") if version_is_less(master['pe_ver'], MANAGE_PUPPET_SERVICE_VERSION)
          puppet_managed = parameters.include?(:managed) ? parameters[:managed] : true
          puppet_ensure = parameters[:ensure]
          puppet_enabled = parameters[:enabled]

          msg = puppet_managed ?
            "Configure agents '#{puppet_ensure}' and #{puppet_enabled ? 'enabled' : 'disabled'}" :
            "Do not manage agents"

          step msg do
            # PE-18799 and remove this conditional
            if use_meep_for_classification?(master[:pe_ver], options)
              class_name = 'pe_infrastructure::agent'
            else
              class_name = 'puppet_enterprise::profile::agent'
            end

            # update pe conf
            update_pe_conf({
              "#{class_name}::puppet_service_managed" => puppet_managed,
              "#{class_name}::puppet_service_ensure" => puppet_ensure,
              "#{class_name}::puppet_service_enabled" => puppet_enabled,
            })
          end
        end

        # Given a hash of parameters, updates the primary master's pe.conf, adding or
        # replacing, or removing the given parameters.
        #
        # To remove a parameter, pass a nil as its value
        #
        # Handles stringifying and quoting namespaced keys, and also preparing non
        # string values using Hocon::ConfigValueFactory.
        #
        # Logs the state of pe.conf before and after.
        #
        # @example
        #   # Assuming pe.conf looks like:
        #   # {
        #   # "bar": "baz"
        #   # "old": "item"
        #   # }
        #
        #   update_pe_conf(
        #     {
        #       "foo" => "a",
        #       "bar" => "b",
        #       "old" => nil,
        #     }
        #   )
        #
        #   # Will produce a pe.conf like:
        #   # {
        #   # "bar": "b"
        #   # "foo": "a"
        #   # }
        #
        # @param parameters [Hash] Hash of parameters to be included in pe.conf.
        # @param pe_conf_file [String] The file to update
        #   (/etc/puppetlabs/enterprise/conf.d/pe.conf by default)
        def update_pe_conf(parameters, pe_conf_file = PE_CONF_FILE)
          step "Update #{pe_conf_file} with #{parameters}" do
            hocon_file_edit_in_place_on(master, pe_conf_file) do |host,doc|
              updated_doc = parameters.reduce(doc) do |pe_conf,param|
                key, value = param

                hocon_key = quoted_hocon_key(key)

                hocon_value = case value
                when String
                  # ensure unquoted string values are quoted for uniformity
                  then value.match(/^[^"]/) ? %Q{"#{value}"} : value
                else Hocon::ConfigValueFactory.from_any_ref(value, nil)
                end

                updated = case value
                when String
                  pe_conf.set_value(hocon_key, hocon_value)
                when nil
                  pe_conf.remove_value(hocon_key)
                else
                  pe_conf.set_config_value(hocon_key, hocon_value)
                end

                updated
              end

              # return the modified document
              updated_doc
            end
            on(master, "cat #{pe_conf_file}")
          end
        end

        # Sync pe.conf from the master to another infrastructure node.
        # Useful when updating pe.conf to reconfigure infrastructure, where
        # you first update_pe_conf then sync_pe_conf to infrastructure hosts.
        #
        # @param [Host] host The host to sync to
        # @param pe_conf_file [String] The file to sync
        #   (/etc/puppetlabs/enterprise/conf.d/pe.conf by default)
        def sync_pe_conf(host, pe_conf_file = PE_CONF_FILE)
          Dir.mktmpdir('sync_pe_conf') do |tmpdir|
            scp_from(master, pe_conf_file, tmpdir)
            scp_to(host, File.join(tmpdir, File.basename(pe_conf_file)), pe_conf_file)
          end
        end

        # If the key is unquoted and does not contain pathing ('.'),
        # quote to ensure that puppet namespaces are protected
        #
        # @example
        #   quoted_hocon_key("puppet_enterprise::database_host")
        #   # => '"puppet_enterprise::database_host"'
        #
        def quoted_hocon_key(key)
          case key
          when /^[^"][^.]+/
            then %Q{"#{key}"}
          else key
          end
        end

        # Return the original pe_ver setting for the passed host.
        # Beaker resets pe_ver to the value of pe_upgrade_ver during its upgrade process.
        # If the hosts's original configuration did not have a pe_ver, return the
        # value of pe_ver set directly in options.  It's the Host['pe_ver'] that
        # gets overwritten by Beaker on upgrade.  So if the original host config did not
        # have a pe_ver set, there should be a pe_ver set in options and we can use
        # that.
        def original_pe_ver(host)
          options[:HOSTS][host.name][:pe_ver] || options[:pe_ver]
        end

        # Returns the version of PE that the host will be upgraded to
        # If no upgrade is planned then just the version of PE to install is returned
        def upgrading_to_pe_ver(host)
          options[:HOSTS][host.name][:pe_upgrade_ver] || options[:pe_ver]
        end

        # @return a Ruby object of any root key in pe.conf.
        #
        # @param key [String] to lookup
        # @param pe_conf_path [String] defaults to /etc/puppetlabs/enterprise/conf.d/pe.conf
        def get_unwrapped_pe_conf_value(key, pe_conf_path = PE_CONF_FILE)
          file_contents = on(master, "cat #{pe_conf_path}").stdout
          # Seem to need to use ConfigFactory instead of ConfigDocumentFactory
          # to get something that we can read values from?
          doc = Hocon::ConfigFactory.parse_string(file_contents)
          hocon_key = quoted_hocon_key(key)
          doc.has_path?(hocon_key) ?
            doc.get_value(hocon_key).unwrapped :
            nil
        end

        # Creates a new /etc/puppetlabs/enterprise/conf.d/nodes/*.conf file for the
        # given host's certname, and adds the passed parameters, or updates with the
        # passed parameters if the file already exists.
        #
        # Does not remove an empty file.
        #
        # @param host [Beaker::Host] to create a node file for
        # @param parameters [Hash] of key value pairs to add to the nodes conf file
        # @param node_conf_path [String] defaults to /etc/puppetlabs/enterprise/conf.d/nodes
        def create_or_update_node_conf(host, parameters, node_conf_path = NODE_CONF_PATH)
          node_conf_file = "#{node_conf_path}/#{host.node_name}.conf"
          step "Create or Update #{node_conf_file} with #{parameters}" do
            if !master.file_exist?(node_conf_file)
              if !master.file_exist?(node_conf_path)
                # potentially create the nodes directory
                on(master, "mkdir #{node_conf_path}")
              end
              # The hocon gem will create a list of comma separated parameters
              # on the same line unless we start with something in the file.
              create_remote_file(master, node_conf_file, %Q|{\n}\n|)
              on(master, "chown pe-puppet #{node_conf_file}")
            end
            update_pe_conf(parameters, node_conf_file)
          end
        end

        def setup_pe_conf(host, hosts, opts={})
          if opts[:type] == :upgrade && use_meep?(host['previous_pe_ver'])
            # In this scenario, Beaker runs the installer such that we make
            # use of recovery code in the configure face of the installer.
            if host['roles'].include?('master')
              step "Updating #{MEEP_DATA_DIR}/conf.d with answers/custom_answers" do
                # merge answers into pe.conf
                if opts[:answers] && !opts[:answers].empty?
                  update_pe_conf(opts[:answers])
                end

                if opts[:custom_answers] && !opts[:custom_answers].empty?
                  update_pe_conf(opts[:custom_answers])
                end
              end
            else
              step "Uploading #{BEAKER_MEEP_TMP}/conf.d that was generated on the master" do
                # scp conf.d to host
                scp_to(host, "#{BEAKER_MEEP_TMP}/conf.d", MEEP_DATA_DIR)
              end
            end
          else
            # Beaker creates a fresh pe.conf using beaker-answers, as if we were doing an install
            generate_installer_conf_file_for(host, hosts, opts)
          end
        end

        def download_pe_conf_if_master(host)
          if host['roles'].include?('master')
            step "Downloading generated #{MEEP_DATA_DIR}/conf.d locally" do
              # scp conf.d over from master
              scp_from(host, "#{MEEP_DATA_DIR}/conf.d", BEAKER_MEEP_TMP)
            end
          end
        end

        # Method to install just the agent nodes
        # This method can be called only after installing PE on infrastructure nodes
        # @param [Array] agent only nodes from Beaker hosts
        # @param [Hash] opts The Beaker options hash
        def install_agents_only_on(agent_nodes, opts)
          unless agent_nodes.empty?
            configure_type_defaults_on(agent_nodes)

             step "Setup frictionless installer on the master" do
               agent_nodes.each do |agent|
                 # If We're *not* running the classic installer, we want
                 # to make sure the master has packages for us.
                 if agent['packaging_platform'] != master['packaging_platform'] # only need to do this if platform differs
                   deploy_frictionless_to_master(agent)
                 end
               end
             end

             step "Install agents" do
               block_on(agent_nodes, {:run_in_parallel => true}) do |host|
                 install_ca_cert_on(host, opts)
                 on(host, installer_cmd(host, opts))
               end
             end

             step "Sign agent certificates" do
               # This will sign all cert requests
               sign_certificate_for(agent_nodes)
             end

             step "Stop puppet agents to avoid interfering with tests" do
               stop_agent_on(agent_nodes, :run_in_parallel => true)
             end

             step "Run puppet on all agent nodes" do
               on agent_nodes, puppet_agent('-t'), :acceptable_exit_codes => [0,2], :run_in_parallel => true
             end

             #Workaround for windows frictionless install, see BKR-943
             agent_nodes.select {|agent| agent['platform'] =~ /windows/}.each do |agent|
               remove_client_datadir(agent)
             end
          end
        end
      end
    end
  end
end
