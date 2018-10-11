require 'beaker'
require 'beaker-puppet'

require 'stringify-hash'
require 'beaker-pe/version'
require 'beaker-pe/install/pe_defaults'
require 'beaker-pe/install/pe_utils'
require 'beaker-pe/install/ca_utils'
require 'beaker-pe/options/pe_version_scraper'
require 'beaker-pe/pe-client-tools/config_file_helper'
require 'beaker-pe/pe-client-tools/install_helper'
require 'beaker-pe/pe-client-tools/executable_helper'

module Beaker
  module DSL
    module PE
      include Beaker::DSL::InstallUtils::PEDefaults
      include Beaker::DSL::InstallUtils::PEUtils
      include Beaker::DSL::InstallUtils::PEClientTools
      include Beaker::DSL::InstallUtils::CAUtils
      include Beaker::Options::PEVersionScraper
      include Beaker::DSL::PEClientTools::ConfigFileHelper
      include Beaker::DSL::PEClientTools::ExecutableHelper
    end
  end
end

# Boilerplate DSL inclusion mechanism:
# First we register our module with the Beaker DSL
Beaker::DSL.register( Beaker::DSL::PE )
