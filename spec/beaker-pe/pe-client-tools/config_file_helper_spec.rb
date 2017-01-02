require 'spec_helper'

class MixedWithConfigFileHelper
  include Beaker::DSL::PEClientTools::ConfigFileHelper
end

describe MixedWithConfigFileHelper do

  it 'has a method to write a config file' do
    expect(subject.respond_to?('write_client_tool_config_on')).not_to be(false)
  end
end
