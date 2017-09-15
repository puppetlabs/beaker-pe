require "beaker/dsl/patterns"
require "beaker/dsl/helpers"
require "beaker/dsl/wrappers"

module Beaker
  module DSL
    module PEClientTools
      module ExecutableHelper

        # puppet-access helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-access command
        # @param [String] args The arguments to puppet-access
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_access_on(*args, &block)
          Private.new.tool(:access, *args, &block)
        end

        # puppet-code helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-code command
        # @param [String] args The arguments to puppet-code
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_code_on(*args, &block)
          Private.new.tool(:code, *args, &block)
        end

        # puppet-job helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-job command
        # @param [String] args The arguments to puppet-job
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_job_on(*args, &block)
          Private.new.tool(:job, *args, &block)
        end

        # puppet-app helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-app command
        # @param [String] args The arguments to puppet-app
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_app_on(*args, &block)
          Private.new.tool(:app, *args, &block)
        end

        # puppet-db helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-db command
        # @param [String] args The arguments to puppet-db
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_db_on(*args, &block)
          Private.new.tool(:db, *args, &block)
        end

        # puppet-query helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-query command
        # @param [String] args The arguments to puppet-query
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_query_on(*args, &block)
          Private.new.tool(:query, *args, &block)
        end

        # puppet-task helper win/lin/osx
        # @param [BEAKER::Host] host The SUT that should run the puppet-task command
        # @param [String] args The arguments to puppet-task
        # @param [Hash] opts options hash to the Beaker Command
        # @param [Block] &block optional block
        def puppet_task_on(*args, &block)
          Private.new.tool(:task, *args, &block)
        end

        # Logs a user in on a SUT with puppet-access/RBAC API (windows)
        # @param [Beaker::Host] host The SUT to perform the login on
        # @param [Scooter::HttpDispatchers::ConsoleDispatcher] credentialed_dispatcher A Scooter dispatcher that has credentials for the user
        # @option attribute_hash [String] :name The environment variable
        # @option attribute_hash [String] :default The default value for the environment variable
        # @option attribute_hash [String] :message A message describing the use of this variable
        # @option attribute_hash [Boolean] :required Used internally by CommandFlag, ignored for a standalone EnvVar
        def login_with_puppet_access_on(host, credentialed_dispatcher, opts={})

          lifetime = opts[:lifetime] || nil
          unless host.platform =~ /win/

            user = credentialed_dispatcher.credentials.login
            password = credentialed_dispatcher.credentials.password
            args = ['login']
            args.push "--lifetime #{lifetime}" if lifetime
            puppet_access_on(host, *args, {:stdin => "#{user}\n#{password}\n"})
          else

            # this is a hack
            # puppet-access needs to support alternative to interactive login
            # create .puppetlabs dir
            cmd = Beaker::Command.new('echo', ['%userprofile%'], :cmdexe => true)
            user_home_dir = host.exec(cmd).stdout.chomp
            win_token_path =  "#{user_home_dir}\\.puppetlabs\\"
            host.exec(Beaker::Command.new('MD', [win_token_path.gsub('\\', '\\\\\\')], :cmdexe => true), :accept_all_exit_codes => true)

            token = credentialed_dispatcher.acquire_token_with_credentials(lifetime)
            create_remote_file(host, "#{win_token_path}\\token", token)
          end
        end

        class Private

          include Beaker::DSL
          include Beaker::DSL::Wrappers
          include Beaker::DSL::Helpers::HostHelpers
          include Beaker::DSL::Patterns

          attr_accessor :logger

          def tool(tool, *args, &block)

            host = args.shift
            @logger = host.logger
            options = {}
            options.merge!(args.pop) if args.last.is_a?(Hash)

            if host.platform =~ /win/i

              program_files = host.exec(Beaker::Command.new('echo', ['%PROGRAMFILES%'], :cmdexe => true)).stdout.chomp
              client_tools_dir = "#{program_files}\\#{['Puppet Labs', 'Client', 'tools', 'bin'].join('\\')}\\"
              tool_executable = "\"#{client_tools_dir}puppet-#{tool.to_s}.exe\""

              #TODO does this need to be more detailed to pass exit codes????
              # TODO make batch file direct output to separate file
              batch_contents =<<-EOS
call #{tool_executable} #{args.join(' ')}
              EOS

              @command = build_win_batch_command( host, batch_contents, {:cmdexe => true})
            else

              tool_executable = '/opt/puppetlabs/client-tools/bin/' << "puppet-#{tool.to_s}"
              @command = Beaker::Command.new(tool_executable, args, {:cmdexe => true})
            end

            result = host.exec(@command, options)

            # Also, let additional checking be performed by the caller.
            if block_given?
              case block.arity
                #block with arity of 0, just hand back yourself
                when 0
                  yield self
                #block with arity of 1 or greater, hand back the result object
                else
                  yield result
              end
            end
            result
          end

          def build_win_batch_command( host, batch_contents, command_options)
            timestamp = Time.new.strftime('%Y-%m-%d_%H.%M.%S')
            # Create Temp file
            # make file fully qualified
            batch_file = "#{host.system_temp_path}\\#{timestamp}.bat"
            create_remote_file(host, batch_file, batch_contents)
            Beaker::Command.new("\"#{batch_file}\"", [], command_options)
          end
        end
      end
    end
  end
end
