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

  context 'puppet-task' do
    let(:tool) {'task'}

    it_behaves_like 'pe-client-tool'
  end

  it 'has a method to login with puppet access' do
    expect(subject.respond_to?('login_with_puppet_access_on')).not_to be(false)
  end

  context 'puppet access login with lifetime parameter' do
    let(:logger) {Beaker::Logger.new}
    let(:test_host) {
      make_host('my_super_host', {
          :roles => ['master', 'agent'],
          :platform => 'linux',
          :type => 'pe'
        }
      )
    }
    let(:credentials) {
      mock = Object.new
      allow(mock).to receive(:login).and_return('T')
      allow(mock).to receive(:password).and_return('Swift')
      mock
    }
    let(:test_dispatcher) {
      mock = Object.new
      allow(mock).to receive(:credentials).and_return(credentials)
      mock
    }

    before do
      allow(logger).to receive(:debug) { true }
      expect(test_host).to be_kind_of(Beaker::Host)
    end

    it 'passes the lifetime value to :puppet_access_on on linux' do
      lifetime_value = '5d'

      expect(subject).to receive(:puppet_access_on).with(
        test_host,
        "login",
        "--lifetime #{lifetime_value}",
        anything
      )

      expect{
        subject.login_with_puppet_access_on(
          test_host,
          test_dispatcher,
          {:lifetime => lifetime_value}
        )
      }.not_to raise_error
    end

    it 'passes the lifetime value to the passed dispatcher on windows' do
      test_host[:platform] = "win-stuff"
      allow(subject).to receive(:create_remote_file)
      lifetime_value = '6d'

      expect(test_dispatcher).to receive(
        :acquire_token_with_credentials
      ).with(lifetime_value)

      expect{
        subject.login_with_puppet_access_on(
          test_host,
          test_dispatcher,
          {:lifetime => lifetime_value}
        )
      }.not_to raise_error
    end
  end
end
