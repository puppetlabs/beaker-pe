module Beaker::DSL::InstallUtils
  # This helper class encapsulates querying feature flag settings from
  # options[:answers] which can be used to drive Beaker's install behavior
  # around new or experimental features, typically in the PE Modules.
  #
  # Also handles initializing feature flag settings from environment variables
  # for CI. In this way, flags can be pulled in without needing to munge
  # Beaker's config file which is often handled inside of a script in Jenkins.
  #
  # Flags are expected to be found in a +feature_flags+ hash in the
  # options[:answers] under the key :feature_flags.  Beaker::OptionHash should
  # ensure that all keys end up as symbols.  If you are programatically
  # constructing the answers, you must take care to use merge() to add
  # elements.
  #
  # @example The use of the pe-modules-next package is handled by:
  #   :answers => {
  #     :feature_flags => {
  #       :pe_modules_next => true
  #     }
  #   }
  #
  # All flag keys are expected to be downcased with hyphens.
  #
  # Environment variables may be uppercased.
  class FeatureFlags
    FLAGS = %w{
      pe_modules_next
    }.freeze

    attr_reader :options

    def initialize(options)
      @options = options
    end

    # Returns the boolean state of the flag as found in options[:answers],
    # or if not found in the answers, then it checks for an environment variable.
    #
    # @param String flag key
    # @return [Boolean,nil] boolean true or false unless not found at all, then nil.
    def flag?(flag)
      key = canonical_key(flag)
      state = flags[key] if flags?
      state = environment_flag?(key) if state.nil?

      case state
      when nil then nil
      else state.to_s == 'true'
      end
    end

    # Updates options[:answers][:feature_flags] with any environment variables
    # found based on FLAGS, but if and only if they are not already present.
    #
    # (existing :answers take precedence)
    def register_flags!
      answers_with_registered_flags = answers
      answers_with_registered_flags[:feature_flags] ||= StringifyHash.new
      new_flags = answers_with_registered_flags[:feature_flags]

      FLAGS.each do |flag|
        key = canonical_key(flag)
        value = flag?(key)
        if !new_flags.include?(key) && !value.nil?
          new_flags[key] = value
        end
      end

      options.merge!(
        :answers => answers_with_registered_flags
      ) if !new_flags.empty?

      options
    end

    private

    # Does the +feature_flags+ hash exist?
    def flags?
      answers? && !answers[:feature_flags].nil?
    end

    def flags
      answers[:feature_flags] || StringifyHash.new
    end

    # Does the +answers+ hash exist?
    def answers?
      !options[:answers].nil?
    end

    def answers
      options[:answers] || StringifyHash.new
    end

    def canonical_key(key)
      key.to_s.downcase.to_sym
    end

    def environmental_keys(key)
      [key.to_s.upcase, key.to_s.downcase]
    end

    def environment_flag?(flag)
      value = nil
      environmental_keys(flag).each do |f|
        value = ENV[f] if ENV.include?(f)
        break if !value.nil?
      end
      value
    end
  end
end
