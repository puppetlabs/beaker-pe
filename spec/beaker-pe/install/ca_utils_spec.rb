require 'spec_helper'
include Beaker::DSL::InstallUtils::CAUtils

describe Beaker::DSL::InstallUtils::CAUtils do
  let(:dummy_pki) {
      {
        :root_cert => 'dummy_root_cert',
        :int_cert => 'dummy_int_cert',
        :int_ca_bundle => 'dummy_int_bundle',
        :int_key  => 'dummy_int_key',
        :int_crl_chain => 'dummy_int_crl_chain',
      }
    }

    before(:each) do
      allow(subject).to receive(:create_chained_pki).and_return(dummy_pki)
    end

  describe 'generate_ca_bundle_on' do
    let(:host) { make_host( 'unixhost', { :platform => 'linux'})}
    let(:bundledir) { '/tmp/ca_bundle' }
    let(:expected) { 
      {
        :root_cert => "#{bundledir}/root_cert",
        :int_cert => "#{bundledir}/int_cert",
        :int_ca_bundle => "#{bundledir}/int_ca_bundle",
        :int_key => "#{bundledir}/int_key",
        :int_crl_chain => "#{bundledir}/int_crl_chain",
      }
    }

    it "generates certs on host" do
      expect(subject).to receive(:on).with(host, "mkdir -p #{bundledir}", :acceptable_exit_codes => [0])
      expect(subject).to receive(:create_remote_file).with(host,"#{bundledir}/root_cert", "dummy_root_cert", :acceptable_exit_codes => [0])
      expect(subject).to receive(:create_remote_file).with(host,"#{bundledir}/int_cert", "dummy_int_cert", :acceptable_exit_codes => [0])
      expect(subject).to receive(:create_remote_file).with(host,"#{bundledir}/int_ca_bundle", "dummy_int_bundle", :acceptable_exit_codes => [0])
      expect(subject).to receive(:create_remote_file).with(host,"#{bundledir}/int_key", "dummy_int_key", :acceptable_exit_codes => [0])
      expect(subject).to receive(:create_remote_file).with(host,"#{bundledir}/int_crl_chain", "dummy_int_crl_chain", :acceptable_exit_codes => [0])
      expect( subject.generate_ca_bundle_on(host,"#{bundledir}") ).to eq(expected)
    end
  end
end