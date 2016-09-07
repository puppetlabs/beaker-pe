module Beaker
  module DSL
    module InstallUtils
      module PEClientTools

        def install_pe_client_tools_on(hosts, opts = {})
          # FIXME: accomodate production released location(s)
          #{{{
          product = 'pe-client-tools'
          required_keys = [:puppet_collection, :pe_client_tools_sha, :pe_client_tools_version]

          unless required_keys.all? { |opt| opts.keys.include?(opt) }
            raise ArgumentError, "The keys #{required_keys.to_s} are required in the opts hash"
          end
          urls = { :dev_builds_url   => "http://builds.delivery.puppetlabs.net",
          }

          opts = urls.merge(opts)

          block_on hosts do |host|
            package_name = nil
            variant, version, arch, codename = host['platform'].to_array
            case host['platform']
            when /el-|fedora|sles|centos|cisco_/
              release_path = "#{opts[:dev_builds_url]}/#{product}/#{ opts[:pe_client_tools_sha] }/artifacts/#{variant}/#{version}/#{opts[:puppet_collection]}/#{arch}"
              package_name = product.dup
              package_name << "-#{opts[:pe_client_tools_version]}-1.#{variant}#{version}.#{arch}.rpm" if opts[:pe_client_tools_version]
            when /debian|ubuntu|cumulus|huaweios/
              release_path = "#{opts[:dev_builds_url]}/#{product}/#{ opts[:pe_client_tools_sha] }/artifacts/deb/#{codename}/#{opts[:puppet_collection]}"
              package_name = product.dup
              package_name << "_#{opts[:pe_client_tools_version]}-1#{host['platform'].codename}_#{arch}.deb" if opts[:pe_client_tools_version]
            when /windows/
              release_path = "#{opts[:dev_builds_url]}/#{product}/#{ opts[:pe_client_tools_sha] }/artifacts/#{variant}"
              package_name = product.dup
              package_name << "-#{opts[:pe_client_tools_version]}-x#{arch}.msi" if opts[:pe_client_tools_version]
            when /osx/
              release_path = "#{opts[:dev_builds_url]}/#{product}/#{ opts[:pe_client_tools_sha] }/artifacts/apple/#{version}/#{opts[:puppet_collection]}/#{arch}"
              package_base = product.dup
              package_base << "-#{opts[:pe_client_tools_version]}" if opts[:pe_client_tools_version]
              package_name = package_base.dup
              package_name << '-1' if opts[:pe_client_tools_version]
              installer    = package_name + '-installer.pkg'
              package_name << ".#{variant}#{version}.dmg" if opts[:pe_client_tools_version]
            else
              raise "install_puppet_agent_on() called for unsupported " +
                "platform '#{host['platform']}' on '#{host.name}'"
            end

            if package_name
              case host['platform']
                when /windows/
                  release_path = opts[:local_package] if opts[:local_package]
                  generic_install_msi_on(host, File.join(release_path, package_name), {}, {:debug => true})
              else
                if opts[:local_package]
                  package_location = opts[:local_package]
                else
                  package_location = File.join('tmp', 'repo_configs', package_name)
                  fetch_http_file(release_path, package_name, copy_dir_local)
                end
                scp_to host, package_location, host.external_copy_base

                if host['platform'] =~ /debian|ubuntu|cumulus|huaweios/
                  on host, "dpkg -i #{package_name}"
                elsif host['platform'] =~ /osx/
                  host.generic_install_dmg(package_name, package_base, installer)
                else
                  host.install_package( product )
                end
              end
            end
          end
          #}}}
        end

      end
    end
  end
end
