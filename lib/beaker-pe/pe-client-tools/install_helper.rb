module Beaker
  module DSL
    module InstallUtils
      module PEClientTools

        def install_pe_client_tools_on(hosts, opts = {})
          product = 'pe-client-tools'
          required_keys = [:puppet_collection, :pe_client_tools_sha, :pe_client_tools_version]

          unless required_keys.all? { |opt| opts.keys.include?(opt) && opts[opt]}
            raise ArgumentError, "The keys #{required_keys.to_s} are required in the opts hash"
          end
          urls = { :dev_builds_url   => "http://builds.delivery.puppetlabs.net",
          }

          opts = urls.merge(opts)
          block_on hosts do |host|
            variant, version, arch, codename = host['platform'].to_array
            package_name = ''
            # If we're installing a tagged version, then the package will be
            # located in a directory named after the tag. Otherwise, look for
            # it by SHA.
            if opts[:pe_client_tools_version] =~ /^\d+(\.\d+)+$/
              directory = opts[:pe_client_tools_version]
            else
              directory = opts[:pe_client_tools_sha]
            end
            case host['platform']
              when /win/
                package_name << product
                release_path = "#{opts[:dev_builds_url]}/#{product}/#{directory}/artifacts/#{variant}"
                package_name << "-#{opts[:pe_client_tools_version]}-x#{arch}.msi"
                generic_install_msi_on(host, File.join(release_path, package_name), {}, {:debug => true})
              when /osx/
                release_path = "#{opts[:dev_builds_url]}/#{product}/#{directory}/artifacts/apple/#{version}/#{opts[:puppet_collection]}/#{arch}"
                package_base = "#{product}-#{opts[:pe_client_tools_version]}"
                package_base << '-1' if opts[:pe_client_tools_version]

                dmg = package_base + ".#{variant}#{version}.dmg"
                copy_dir_local = File.join('tmp', 'repo_configs')
                fetch_http_file(release_path, dmg, copy_dir_local)
                scp_to host, File.join(copy_dir_local, dmg), host.external_copy_base

                package_name = package_base + '*'
                installer = package_name + '-installer.pkg'
                host.generic_install_dmg(dmg, package_name, installer)
              else
                install_dev_repos_on(product, host, directory, '/tmp/repo_configs',{:dev_builds_url => opts[:dev_builds_url]})
                host.install_package('pe-client-tools')
            end
          end
        end

        # Taken from puppet acceptance lib
        # Install development repos
        def install_dev_repos_on(package, host, sha, repo_configs_dir, opts={})
          platform = host['platform'] =~ /^(debian|ubuntu)/ ? host['platform'].with_version_codename : host['platform']
          platform_configs_dir = File.join(repo_configs_dir, platform)

          case platform
            when /^(fedora|el|centos|sles)-(\d+)-(.+)$/
              variant = (($1 == 'centos') ? 'el' : $1)
              fedora_prefix = ((variant == 'fedora') ? 'f' : '')
              version = $2
              arch = $3

              pattern = 'pl-%s-%s-%s-%s%s-%s.repo'

              repo_filename = pattern % [
                  package,
                  sha,
                  variant,
                  fedora_prefix,
                  version,
                  arch
              ]

              repo = fetch_http_file(
                  "%s/%s/%s/repo_configs/rpm/" % [opts[:dev_builds_url],package, sha],
                  repo_filename,
                  platform_configs_dir
              )

              if /sles/i.match(platform)
                scp_to(host, repo, '/etc/zypp/repos.d/')
              else
                scp_to(host, repo, '/etc/yum.repos.d/')
              end

            when /^(debian|ubuntu)-([^-]+)-(.+)$/
              variant = $1
              version = $2
              arch = $3

              list = fetch_http_file(
                  "%s/%s/%s/repo_configs/deb/" % [opts[:dev_builds_url],package, sha],
                  "pl-%s-%s-%s.list" % [package, sha, version],
                  platform_configs_dir
              )

              scp_to host, list, '/etc/apt/sources.list.d'
              if variant == 'ubuntu' && version.split('.').first.to_i >= 18
                apt_conf_content = 'Acquire::AllowInsecureRepositories "true";'
              else
                apt_conf_content = 'APT::Get::AllowUnauthenticated "true";'
              end
              create_remote_file(host, '/etc/apt/apt.conf.d/99trust-all', apt_conf_content)
              on host, 'apt-get update'
            else
              host.logger.notify("No repository installation step for #{platform} yet...")
          end
        end
      end
    end
  end
end
