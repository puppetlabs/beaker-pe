require 'spec_helper'
require 'scooter'

class MixedWithExecutableHelper
  include Beaker::DSL::PEClientTools::ExecutableHelper
end

describe MixedWithExecutableHelper do

  let(:method_name)   { "puppet_#{tool}_on"}

  shared_examples 'pe-client-tool' do

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

  context 'puppet access login with lifetime parameter' do
    let(:logger) {Beaker::Logger.new}
    let(:test_host) {Beaker::Host.create('my_super_host',
                                         {:roles => ['master', 'agent'],
                                          :platform => 'linux',
                                          :type => 'pe'},
                                          make_opts)}
    let(:username) {'T'}
    let(:password) {'Swift'}
    let(:credentials) {{:login => username, :password => password}}
    let(:test_dispatcher) {Scooter::HttpDispatchers::ConsoleDispatcher.new('my_super_host', credentials)}

    before do
      allow(logger).to receive(:debug) { true }
      expect(test_dispatcher).to be_kind_of(Scooter::HttpDispatchers::ConsoleDispatcher)
      expect(test_host).to be_kind_of(Beaker::Host)
      expect(test_host).to receive(:exec)
    end

    it 'accepts correct value' do
      expect{subject.login_with_puppet_access_on(test_host, test_dispatcher, {:lifetime => '5d'})}.not_to raise_error
    end
  end
end
