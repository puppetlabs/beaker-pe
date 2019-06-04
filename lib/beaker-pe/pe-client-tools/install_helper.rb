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

        # `install_dev_repos_on` is used in various projects in the puppetlabs namespace;
        # when they are all switched to call `install_puppetlabs_dev_repo`, this method
        # can be removed.
        def install_dev_repos_on(package, host, sha, repo_configs_dir, opts={})
          install_puppetlabs_dev_repo(host, package, sha, repo_configs_dir, opts)
        end
      end
    end
  end
end
