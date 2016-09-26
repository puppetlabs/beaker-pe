require "beaker/dsl/patterns"

module Beaker
  module DSL
    module PEClientTools
      module ConfigFileHelper

        # Helper method to write config files for pe-client-tools
        # @param [Beaker::Host] host The beaker host that gets the config file
        # @param [String] config_level 'user' or 'global'
        # @param [String] tool 'access', 'code', 'db', 'query', 'orchestrator', 'job', 'app'
        # @param [String] contents The contents of the config file
        def write_client_tool_config_on(host, config_level, tool, contents)

          # TODO take a hash and parse file or take literal string

          file = "#{Private.config_path(host, config_level)}/#{Private.file_name(tool)}"
          create_remote_file(host, file, contents)
        end


        class Private

          require 'beaker/dsl/patterns'

          extend Beaker::DSL
          extend Beaker::DSL::Patterns

          def self.file_name(tool)
            if tool =~ /orchestrator|job|app/i
              'orchestrator.conf'
            elsif tool =~ /code/i
              'puppet-code.conf'
            elsif tool =~ /access/i
              'puppet-access.conf'
            elsif tool =~ /db|query/i
              'puppetdb.conf'
            else
              raise ArgumentError.new("Unknown pe-client-tool type '#{tool}'")
            end
          end

          def self.config_path(host, config_level)

            puppetlabs_dir = 'puppetlabs'
            puppetlabs_dir.prepend('.') if config_level == 'user'
            client_tools_path_array = [puppetlabs_dir, 'client-tools']

            case config_level

              when /global/
                @base_path = global_base_path(host)
              when /user/
                @base_path = home_dir(host)
              else
                raise ArgumentError.new("Unknown config level #{config_level}")
            end

            client_tools_dir = client_tools_path_array.unshift(@base_path).join(path_separator(host))
            opts = {:cmdexe => true}

            if host.platform =~ /win/
              host.exec(Beaker::Command.new('MD', [client_tools_dir.gsub('\\', '\\\\\\')], opts), :accept_all_exit_codes => true)
            else
              host.exec(Beaker::Command.new("mkdir -p #{client_tools_dir}", [], opts), :accept_all_exit_codes => true)
            end
            client_tools_dir
          end

          def self.home_dir(host)

            if (host.platform =~ /win/) then
              @cmd = Beaker::Command.new('echo', ['%userprofile%'], :cmdexe => true)
            else
              @cmd = Beaker::Command.new('echo', ['$HOME'])
            end
            host.exec(@cmd).stdout.chomp
          end

          def self.global_base_path(host)

            (host.platform =~ /win/) ?host.exec(Beaker::Command.new('echo', ['%PROGRAMDATA%'], :cmdexe => true)).stdout.chomp : '/etc//'
          end

          def self.path_separator(host)

            (host.platform =~ /win/) ? '\\' : '/'
          end
        end
      end
    end
  end
end
