require 'stringify-hash'
require 'beaker-pe/version'
require 'beaker-pe/install/pe_utils'
require 'beaker-pe/options/pe_version_scraper'
require 'beaker-pe/pe-client-tools/config_file_helper'
require 'beaker-pe/pe-client-tools/install_helper'
require 'beaker-pe/pe-client-tools/executable_helper'

module Beaker
  module DSL
    module PE
      include Beaker::DSL::InstallUtils::PEUtils
      include Beaker::DSL::InstallUtils::PEClientTools
      include Beaker::Options::PEVersionScraper
      include Beaker::DSL::PEClientTools::ConfigFileHelper
      include Beaker::DSL::PEClientTools::ExecutableHelper
    end
  end
end

# Boilerplate DSL inclusion mechanism:
# First we register our module with the Beaker DSL
Beaker::DSL.register( Beaker::DSL::PE )

# Second,We need to reload the DSL, but before we had reloaded
# it in the global namespace, which result in errors colliding
# with other gems rightfully not expecting beaker's dsl to
# be available at the global level.
module Beaker
  class TestCase
    include Beaker::DSL
  end
end
