require 'spec_helper'

class MixedWithExecutableHelper
  include Beaker::DSL::PEClientTools::ExecutableHelper
end

describe MixedWithExecutableHelper do

  let(:method_name)   { "puppet_#{tool}_on"}

  shared_examples 'pe-client-tool'do

    it 'has a method to execute the tool' do
      expect(subject.respond_to?(method_name)).not_to be(false)
    end
  end

  context 'puppet-code' do
    let(:tool) {'code'}

    it_behaves_like 'pe-client-tool'
  end

  context 'puppet-access' do
    let(:tool) {'access'}

    it_behaves_like 'pe-client-tool'
  end

  context 'puppet-job' do
    let(:tool) {'job'}

    it_behaves_like 'pe-client-tool'
  end

  context 'puppet-app' do
    let(:tool) {'app'}

    it_behaves_like 'pe-client-tool'
  end

  context 'puppet-db' do
    let(:tool) {'db'}

    it_behaves_like 'pe-client-tool'
  end

  context 'puppet-query' do
    let(:tool) {'query'}

    it_behaves_like 'pe-client-tool'
  end

  it 'has a method to login with puppet access' do
    expect(subject.respond_to?('login_with_puppet_access_on')).not_to be(false)
  end
end
