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


# This is commented out because Beaker is going to include this
# library itself until version 3.0.
# # Boilerplate DSL inclusion mechanism:
# # First we register our module with the Beaker DSL
# Beaker::DSL.register( Beaker::DSL::PE )
# # Then we have to re-include our amended DSL in the TestCase,
# # because in general, the DSL is included in TestCase far
# # before test files are executed, so our amendments wouldn't
# # come through otherwise
# include Beaker::DSL
