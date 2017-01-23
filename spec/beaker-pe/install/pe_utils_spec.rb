require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::InstallUtils
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns
  include Beaker::DSL::PE

  attr_accessor :hosts, :metadata, :options

  def initialize
    @metadata = {}
    @options = {}
  end

  # Because some the methods now actually call out to the `step` method, we need to
  # mock out `metadata` that is initialized in a test case.
  def metadata
    @metadata ||= {}
  end

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLInstallUtils do
  let(:presets)       { Beaker::Options::Presets.new }
  let(:opts)          { presets.presets.merge(presets.env_vars) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                      :platform => 'linux',
                                      :roles => [ 'agent' ],
                                      :type => 'pe'}, 4 ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts[3][:platform] = 'eos'
                        basic_hosts  }
  let(:hosts_sorted)  { [ hosts[1], hosts[0], hosts[2], hosts[3] ] }
  let(:winhost)       { make_host( 'winhost', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :type => 'pe',
                                                :working_dir => '/tmp' } ) }
  let(:machost)       { make_host( 'machost', { :platform => 'osx-10.9-x86_64',
                                                :pe_ver => '3.0',
                                                :type => 'pe',
                                                :working_dir => '/tmp' } ) }
  let(:unixhost)      { make_host( 'unixhost', { :platform => 'linux',
                                                 :pe_ver => '3.0',
                                                 :type => 'pe',
                                                 :working_dir => '/tmp',
                                                 :dist => 'puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386' } ) }
  let(:eoshost)       { make_host( 'eoshost', { :platform => 'eos',
                                                :pe_ver => '3.0',
                                                :type => 'pe',
                                                :working_dir => '/tmp',
                                                :dist => 'puppet-enterprise-3.7.1-rc0-78-gffc958f-eos-4-i386' } ) }

  context '#prep_host_for_upgrade' do

    it 'sets per host options before global options' do
      opts['pe_upgrade_ver'] = 'options-specific-var'
      hosts.each do |host|
        host['pe_upgrade_dir'] = 'host-specific-pe-dir'
        host['pe_upgrade_ver'] = 'host-specific-pe-ver'
        subject.prep_host_for_upgrade(host, opts, 'argument-specific-pe-dir')
        expect(host['pe_dir']).to eq('host-specific-pe-dir')
        expect(host['pe_ver']).to eq('host-specific-pe-ver')
      end
    end

    it 'sets global options when no host options are available' do
      opts['pe_upgrade_ver'] = 'options-specific-var'
      hosts.each do |host|
        host['pe_upgrade_dir'] = nil
        host['pe_upgrade_ver'] = nil
        subject.prep_host_for_upgrade(host, opts, 'argument-specific-pe-dir')
        expect(host['pe_dir']).to eq('argument-specific-pe-dir')
        expect(host['pe_ver']).to eq('options-specific-var')
      end
    end

    it 'calls #load_pe_version when neither global or host options are present' do
      opts['pe_upgrade_ver'] = nil
      hosts.each do |host|
        host['pe_upgrade_dir'] = nil
        host['pe_upgrade_ver'] = nil
        expect( Beaker::Options::PEVersionScraper ).to receive(:load_pe_version).and_return('file_version')
        subject.prep_host_for_upgrade(host, opts, 'argument-specific-pe-dir')
        expect(host['pe_ver']).to eq('file_version')
        expect(host['pe_dir']).to eq('argument-specific-pe-dir')
      end
    end
  end

  context '#configure_pe_defaults_on' do
    it 'uses aio paths for hosts of role aio' do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host[:roles] = host[:roles] | ['aio']
      end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_pe_defaults_on( hosts )
    end

    it 'uses pe paths for hosts of type pe' do
      hosts.each do |host|
        host[:type] = 'pe'
      end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_pe_defaults_on( hosts )
    end

    it 'uses aio paths for hosts of type aio' do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host[:type] = 'aio'
      end
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_pe_defaults_on( hosts )
    end

    it 'uses no paths for hosts with no type' do
      hosts.each do |host|
        host[:type] = nil
      end
      expect(subject).to receive(:add_pe_defaults_on).never
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).never

      subject.configure_pe_defaults_on( hosts )
    end

    it 'uses aio paths for hosts of version >= 4.0' do
      hosts.each do |host|
        host[:pe_ver] = '4.0'
        end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_pe_defaults_on( hosts )
    end

    it 'uses pe paths for hosts of version < 4.0' do
      hosts.each do |host|
        host[:pe_ver] = '3.8'
      end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_pe_defaults_on( hosts )
    end

  end

  describe 'sorted_hosts' do
    it 'can reorder so that the master comes first' do
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      expect( subject.sorted_hosts ).to be === hosts
    end

    it 'leaves correctly ordered hosts alone' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.sorted_hosts ).to be === hosts
    end

    it 'does not allow nil entries' do
      allow( subject ).to receive( :options ).and_return( { :masterless => true } )
      masterless_host = [basic_hosts[0]]
      allow( subject ).to receive( :hosts ).and_return( masterless_host )
      expect( subject.sorted_hosts ).to be === masterless_host
    end
  end

  describe 'installer_cmd' do

    it 'generates a unix PE install command for a unix host' do
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['pe_installer_conf_setting'] = '-a /tmp/answers'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer -a /tmp/answers"
    end

    it 'generates a unix PE frictionless install command for a unix host with role "frictionless"' do
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_ver'] = '3.8.0'
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      expect( subject.installer_cmd( the_host, {} ) ).to be ===  "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.8.0/install.bash && bash install.bash"
    end

    it 'generates a unix PE frictionless install command for a unix host with role "frictionless" and "frictionless_options"' do
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_ver'] = '3.8.0'
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      the_host['frictionless_options'] = { 'main' => { 'dns_alt_names' => 'puppet' } }
      expect( subject.installer_cmd( the_host, {} ) ).to be ===  "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.8.0/install.bash && bash install.bash main:dns_alt_names=puppet"
    end

    it 'generates a osx PE install command for a osx host' do
      the_host = machost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && hdiutil attach .dmg && installer -pkg /Volumes/puppet-enterprise-3.0/puppet-enterprise-installer-3.0.pkg -target /"
    end

    it 'calls the EOS PE install command for an EOS host' do
      the_host = eoshost.dup
      expect( the_host ).to receive( :install_from_file ).with( /swix$/ )
      subject.installer_cmd( the_host, {} )
    end

    it 'generates a unix PE install command in verbose for a unix host when pe_debug is enabled' do
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['pe_installer_conf_setting'] = '-a /tmp/answers'
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer -D -a /tmp/answers"
    end

    it 'generates a osx PE install command in verbose for a osx host when pe_debug is enabled' do
      the_host = machost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && hdiutil attach .dmg && installer -verboseR -pkg /Volumes/puppet-enterprise-3.0/puppet-enterprise-installer-3.0.pkg -target /"
    end

    it 'generates a unix PE frictionless install command in verbose for a unix host with role "frictionless" and pe_debug is enabled' do
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_ver'] = '3.8.0'
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.8.0/install.bash && bash -x install.bash"
    end
  end

  describe 'install_via_msi?' do
    it 'returns true if pe_version is before PE 2016.4.0' do
      the_host = winhost.dup
      the_host['roles'] = ['frictionless']
      the_host['pe_ver'] = '2015.2.3'
      expect(subject.install_via_msi?(the_host)).to eq(true)
    end

    it 'returns nil if pe_version is PE 2016.4.0 or newer' do
      the_host = winhost.dup
      the_host['roles'] = ['frictionless']
      the_host['pe_ver'] = '2016.4.2'
      expect(subject.install_via_msi?(the_host)).to be nil
    end

    it 'returns true if pe_version is 2016.4.0 and platform is windows-2008r2 bug' do
      the_host = winhost.dup
      the_host['roles'] = ['frictionless']
      the_host['platform'] = 'windows-2008r2'
      the_host['pe_ver'] = '2016.4.0'
      expect(subject.install_via_msi?(the_host)).to eq(true)
    end

    it 'returns false if pe_version is 2016.4.3 and platform is windows-2008r2 bug' do
      the_host = winhost.dup
      the_host['roles'] = ['frictionless']
      the_host['platform'] = 'windows-2008r2'
      the_host['pe_ver'] = '2016.4.3'
      expect(subject.install_via_msi?(the_host)).to eq(false)
    end

  end

  describe 'higgs installer' do
    let(:host) { unixhost }
    let(:higgs_regex) { %r{cd .* ; nohup \./puppet-enterprise-installer <<<#{higgs_answer} .*} }
    before(:each) do
      host['pe_installer'] = 'puppet-enterprise-installer'
    end

    def prep_host(host)
      allow(subject).to receive(:sleep)
      allow(host).to receive(:tmpdir).and_return('/tmp')
      allow(subject).to receive(:fetch_pe)
      expect(subject).to receive(:on).with(host, higgs_regex, opts).once
      result = double(Beaker::Result, :stdout => 'Please go to https://somewhere in your browser to continue installation')
      expect(subject).to receive(:on).with(host, %r{cd .* && cat .*}, anything)
        .and_return(result)
    end

    context 'for legacy installer' do
      let(:higgs_answer) { 'Y' }

      context 'the higgs_installer_cmd' do
        it 'returns correct command to invoke Higgs' do
          expect(subject.higgs_installer_cmd(host)).to match(higgs_regex)
        end
      end

      context 'the do_higgs_install' do
        it 'submits the correct installer cmd to invoke Higgs' do
          prep_host(host)
          subject.do_higgs_install(host, opts)
        end
      end
    end

    context 'for meep installer' do
      let(:higgs_answer) { '1' }

      before(:each) do
        host['pe_ver'] = '2016.2.0'
      end

      context 'the higgs_installer_cmd' do
        it 'submits correct command to invoke Higgs' do
          subject.prepare_host_installer_options(host)
          expect(subject.higgs_installer_cmd(host)).to match(higgs_regex)
        end
      end

      context 'the do_higgs_install' do
        it 'submits the correct installer cmd to invoke Higgs' do
          prep_host(host)
          subject.do_higgs_install(host, opts)
        end
      end
    end
  end

  describe 'prepare_host_installer_options' do
    let(:legacy_settings) do
      {
        :pe_installer_conf_file => '/tmp/answers',
        :pe_installer_conf_setting => '-a /tmp/answers',
      }
    end
    let(:meep_settings) do
      {
        :pe_installer_conf_file => '/tmp/pe.conf',
        :pe_installer_conf_setting => '-c /tmp/pe.conf',
      }
    end
    let(:host) { unixhost }

    before(:each) do
      host['pe_ver'] = pe_ver
      subject.prepare_host_installer_options(host)
    end

    def slice_installer_options(host)
      host.host_hash.select { |k,v| [ :pe_installer_conf_file, :pe_installer_conf_setting].include?(k) }
    end

    context 'when version < 2016.2.0' do
      let(:pe_ver) { '3.8.5' }

      it 'sets legacy settings' do
        expect(slice_installer_options(host)).to eq(legacy_settings)
      end
    end

    context 'when version >= 2016.2.0' do
      let (:pe_ver) { '2016.2.0' }

      it 'test use_meep?' do
        expect(subject.use_meep?('3.8.5')).to eq(false)
        expect(subject.use_meep?('2016.1.2')).to eq(false)
        expect(subject.use_meep?('2016.2.0')).to eq(true)
        expect(subject.use_meep?('2016.2.0-rc1-gabcdef')).to eq(true)
      end

      it 'sets meep settings' do
        expect(slice_installer_options(host)).to eq(meep_settings)
      end
    end
  end

  describe 'use_meep_for_classification?' do
    let(:feature_flag) { nil }
    let(:environment_feature_flag) { nil }
    let(:answers) do
      {
        :answers => {
          'feature_flags' => {
            'pe_modules_next' => feature_flag,
          },
        },
      }
    end
    let(:options) do
      feature_flag.nil? ?
        opts :
        opts.merge(answers)
    end
    let(:host) { unixhost }

    before(:each) do
      subject.options = options
      if !environment_feature_flag.nil?
        ENV['PE_MODULES_NEXT'] = environment_feature_flag
      end
    end

    after(:each) do
      ENV.delete('PE_MODULES_NEXT')
    end

    it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
    it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(false) }

    context 'feature flag false' do
      let(:feature_flag) { false }

      it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
      it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(false) }
    end

    context 'feature flag true' do
      let(:feature_flag) { true }

      it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
      it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(true) }
    end

    context 'environment feature flag true' do
      let(:environment_feature_flag) { 'true' }

      it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
      it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(true) }

      context 'answers feature flag false' do
        let(:feature_flag) { false }

        it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
        it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(false) }
      end
    end

    context 'environment feature flag false' do
      let(:environment_feature_flag) { 'false' }

      it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
      it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(false) }

      context 'answers feature flag true' do
        let(:feature_flag) { true }

        it { expect(subject.use_meep_for_classification?('2017.1.0', options)).to eq(false) }
        it { expect(subject.use_meep_for_classification?('2017.2.0', options)).to eq(true) }
      end
    end
  end

  describe 'generate_installer_conf_file_for' do
    let(:master) { hosts.first }

    it 'generates a legacy answer file if < 2016.2.0' do
      master['pe_installer_conf_file'] = '/tmp/answers'
      expect(subject).to receive(:create_remote_file).with(
        master,
        '/tmp/answers',
        %r{q_install=y.*q_puppetmaster_certname=#{master}}m
      )
      subject.generate_installer_conf_file_for(master, hosts, opts)
    end

    it 'generates a meep config file if >= 2016.2.0' do
      master['pe_installer_conf_file'] = '/tmp/pe.conf'
      master['pe_ver'] = '2016.2.0'
      expect(subject).to receive(:create_remote_file).with(
        master,
        '/tmp/pe.conf',
        %r{\{.*"puppet_enterprise::puppet_master_host": "#{master.hostname}"}m
      )
      subject.generate_installer_conf_file_for(master, hosts, opts)
    end
  end

  describe 'register_feature_flags!' do
    it 'does nothing if no flag is set' do
      expect(subject.register_feature_flags!(opts)).to eq(opts)
      expect(opts[:answers]).to be_nil
    end

    context 'with flag set' do
      before(:each) do
        ENV['PE_MODULES_NEXT'] = 'true'
      end

      after(:each) do
        ENV.delete('PE_MODULES_NEXT')
      end

      it 'updates answers' do
        expect(subject.register_feature_flags!(opts)).to match(opts.merge({
          :answers => {
            :feature_flags => {
              :pe_modules_next => true
            }
          }
        }))
      end

      context 'and answer explicitly set' do
        let(:answers) do
          {
            :answers => {
              'feature_flags' => {
                'pe_modules_next' => false
              }
            }
          }
        end

        before(:each) do
          opts.merge!(answers)
        end

        it 'keeps explicit setting' do
          expect(subject.register_feature_flags!(opts)).to match(opts.merge(answers))
        end
      end
    end
  end

  describe 'feature_flag?' do

    context 'without :answers' do
      it 'is nil for pe_modules_next' do
        expect(subject.feature_flag?('pe_modules_next', opts)).to eq(nil)
        expect(subject.feature_flag?(:pe_modules_next, opts)).to eq(nil)
      end
    end

    context 'with :answers but no flag' do
      before(:each) do
        opts[:answers] = {}
      end

      it 'is nil for pe_modules_next' do
        expect(subject.feature_flag?('pe_modules_next', opts)).to eq(nil)
        expect(subject.feature_flag?(:pe_modules_next, opts)).to eq(nil)
      end
    end

    context 'with answers set' do
      let(:options) do
        opts.merge(
          :answers => {
            'feature_flags' => {
              'pe_modules_next' => flag
            }
          }
        )
      end

      context 'false' do
        let(:flag) { false }
        it { expect(subject.feature_flag?('pe_modules_next', options)).to eq(false) }
        it { expect(subject.feature_flag?(:pe_modules_next, options)).to eq(false) }
      end

      context 'true' do
        let(:flag) { true }
        it { expect(subject.feature_flag?('pe_modules_next', options)).to eq(true) }
        it { expect(subject.feature_flag?(:pe_modules_next, options)).to eq(true) }

        context 'as string' do
          let(:flag) { 'true' }
          it { expect(subject.feature_flag?('pe_modules_next', options)).to eq(true) }
          it { expect(subject.feature_flag?(:pe_modules_next, options)).to eq(true) }
        end
      end
    end
  end

  describe 'setup_beaker_answers_opts' do
    let(:opts) { {} }
    let(:host) { hosts.first }

    context 'for legacy installer' do
      it 'adds option for bash format' do
        expect(subject.setup_beaker_answers_opts(host, opts)).to eq(
          opts.merge(
            :format => :bash,
            :include_legacy_database_defaults => false,
          )
        )
      end
    end

    context 'for meep installer' do
      before(:each) do
        host['pe_ver'] = '2016.2.0'
      end

      it 'adds option for hiera format' do
        expect(subject.setup_beaker_answers_opts(host, opts)).to eq(
          opts.merge(
            :format => :hiera,
            :include_legacy_database_defaults => false,
          )
        )
      end

      context 'with pe-modules-next' do
        let(:options) do
          opts.merge(
            :answers => {
              :feature_flags => {
                :pe_modules_next => true
              }
            }
          )
        end

        it 'adds meep_schema_version' do
          expect(subject.setup_beaker_answers_opts(host, options)).to eq(
            options.merge(
              :format => :hiera,
              :include_legacy_database_defaults => false,
              :meep_schema_version => '2.0',
            )
          )
        end
      end

      context 'when upgrading' do
        let(:opts) { { :type => :upgrade } }

        context 'from meep' do
          it 'sets legacy password defaults false' do
            host['pe_ver'] = '2016.2.1'
            host['previous_pe_ver'] = '2016.2.0'
            expect(subject.setup_beaker_answers_opts(host, opts)).to eq(
              opts.merge(
                :format => :hiera,
                :include_legacy_database_defaults => false,
              )
            )
          end
        end

        context 'from legacy' do
          it 'sets legacy password defaults to true' do
            host['previous_pe_ver'] = '3.8.5'
            expect(subject.setup_beaker_answers_opts(host, opts)).to eq(
              opts.merge(
                :format => :hiera,
                :include_legacy_database_defaults => true,
              )
            )
          end
        end
      end
    end
  end

  describe 'ignore_gpg_key_warning_on_hosts' do
    let(:on_cmd) { "echo 'APT { Get { AllowUnauthenticated \"1\"; }; };' >> /etc/apt/apt.conf" }
    let(:deb_host) do
      host = hosts.first
      host['platform'] = 'debian'
      host
    end

    context 'mixed platforms' do
      before(:each) do
        hosts[0]['platform'] = 'centos'
        hosts[1]['platform'] = 'debian'
        hosts[2]['platform'] = 'ubuntu'
      end

      it 'does nothing on el platforms' do
        expect(subject).not_to receive(:on).with(hosts[0], on_cmd)
        subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
      end

      it 'adds in apt ignore gpg-key warning' do
        expect(subject).to receive(:on).with(hosts[1], on_cmd)
        expect(subject).to receive(:on).with(hosts[2], on_cmd)
        subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
      end
    end

    context 'mixed pe_versions' do
      before(:each) do
        hosts[0]['platform'] = 'debian'
        hosts[0]['pe_ver'] = '2016.4.0'
        hosts[1]['platform'] = 'debian'
        hosts[1]['pe_ver'] = '3.8.4'
      end

      it 'adds apt gpg-key ignore to required hosts' do
        expect(subject).not_to receive(:on).with(hosts[0], on_cmd)
        expect(subject).to receive(:on).with(hosts[1], on_cmd)
        subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
      end
    end

    context 'PE versions earlier than 3.8.7' do
      ['3.3.2', '3.7.3', '3.8.2', '3.8.4', '3.8.5', '3.8.6'].each do |pe_ver|
        it "Adds apt gpg-key ignore on PE #{pe_ver}" do
          deb_host['pe_ver'] = pe_ver
          expect(subject).to receive(:on).with(deb_host, on_cmd)
          subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
        end
      end
    end

    context 'PE versions between 2015.2.0 and 2016.2.1' do
      ['2015.2.0', '2015.3.1', '2016.1.2', '2016.2.1'].each do |pe_ver|
        it "Adds apt gpg-key ignore on PE #{pe_ver}" do
          deb_host['pe_ver'] = pe_ver
          expect(subject).to receive(:on).with(deb_host, on_cmd)
          subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
        end
      end
    end

    ['2016.4.0', '2016.5.1', '2017.1.0'].each do |pe_ver|
      context "PE #{pe_ver}" do
        it 'does nothing' do
          deb_host['pe_ver'] = pe_ver
          expect(subject).not_to receive(:on).with(deb_host, on_cmd)
          subject.ignore_gpg_key_warning_on_hosts(hosts, opts)
        end
      end
    end
  end

  describe 'fetch_pe' do

    it 'can push a local PE .tar.gz to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is a .tar.gz
      unixhost['pe_dir'] = '/local/file/path'
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :scp_to ).with( unixhost, "#{ path }/#{ filename }#{ extension }", "#{ unixhost['working_dir'] }/#{ filename }#{ extension }" ).once
      expect( subject ).to receive( :on ).with( unixhost, /gunzip/ ).once
      expect( subject ).to receive( :on ).with( unixhost, /tar -xvf/ ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar from a URL to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ) do |arg|
        if arg =~ /.tar.gz/ #there is no .tar.gz link, only a .tar
          false
        else
          true
        end
      end
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar'
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar from a URL to #fetch_and_push_pe' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ) do |arg|
        if arg =~ /.tar.gz/ #there is no .tar.gz link, only a .tar
          false
        else
          true
        end
      end
      allow( subject ).to receive( :on ).and_return( true )

      filename = "#{ unixhost['dist'] }"
      extension = '.tar'
      expect( subject ).to receive( :fetch_and_push_pe ).with( unixhost, anything, filename, extension ).once
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; cat #{ filename }#{ extension } | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {:fetch_local_then_push_to_host => true} )
    end

    it 'can download a PE .tar.gz from a URL to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is a tar.gz
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | gunzip | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar.gz from a URL to #fetch_and_push_pe' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is a tar.gz
      allow( subject ).to receive( :on ).and_return( true )

      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :fetch_and_push_pe ).with( unixhost, anything, filename, extension ).once
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; cat #{ filename }#{ extension } | gunzip | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {:fetch_local_then_push_to_host => true} )
    end

    it 'calls the host method to get an EOS .swix file from a URL' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #skip file check

      expect( eoshost ).to receive( :get_remote_file ).with( /swix$/ ).once
      subject.fetch_pe( [eoshost], {} )
    end

    it 'can push a local PE package to a windows host' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is present
      winhost['dist'] = 'puppet-enterprise-3.0'
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = winhost['pe_dir']
      filename = "puppet-enterprise-#{ winhost['pe_ver'] }"
      extension = '.msi'
      expect( subject ).to receive( :scp_to ).with( winhost, "#{ path }/#{ filename }#{ extension }", "#{ winhost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [winhost], {} )

    end

    it 'can download a PE dmg from a URL to a mac host' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is  not local
      allow( subject ).to receive( :on ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      expect( subject ).to receive( :on ).with( machost, "cd #{ machost['working_dir'] }; curl -O #{ path }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [machost], {} )
    end

    it 'can push a PE dmg to a mac host' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is present
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      expect( subject ).to receive( :scp_to ).with( machost, "#{ path }/#{ filename }#{ extension }", "#{ machost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [machost], {} )
    end

    it "does nothing for a frictionless agent for PE >= 3.2.0" do
      unixhost['roles'] << 'frictionless'
      unixhost['pe_ver'] = '3.2.0'

      expect( subject).to_not receive(:scp_to)
      expect( subject).to_not receive(:on)
      subject.fetch_pe( [unixhost], {} )
    end
  end

  describe 'do_install' do
    it 'can perform a simple installation' do
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :sign_certificate_for ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :sleep_until_puppetdb_started ).and_return( true )
      allow( subject ).to receive( :max_version ).with(anything, '3.8').and_return('3.0')
      allow( subject ).to receive( :wait_for_host_in_dashboard ).and_return( true )
      allow( subject ).to receive( :puppet_agent ) do |arg|
        "puppet agent #{arg}"
      end
      allow( subject ).to receive( :puppet ) do |arg|
        "puppet #{arg}"
      end

      allow( subject ).to receive( :hosts ).and_return( hosts )
      #create answers file per-host, except windows
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      #run installer on all hosts
      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :install_msi_on ).with ( any_args ) do | host, msi_path, msi_opts, opts |
        expect( host ).to eq( hosts[1] )
      end.once
      expect( subject ).to receive( :on ).with( hosts[2], / hdiutil attach puppet-enterprise-3.0-osx-10.9-x86_64.dmg && installer -pkg \/Volumes\/puppet-enterprise-3.0\/puppet-enterprise-installer-3.0.pkg -target \// ).once
      expect( hosts[3] ).to receive( :install_from_file ).with( /swix$/ ).once
      #does extra mac/EOS specific commands
      expect( subject ).to receive( :on ).with( hosts[2], /puppet config set server/ ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet config set server/ ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet config set certname/ ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet config set certname/ ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [1] ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet agent -t/, :acceptable_exit_codes => [0, 1] ).once
      #sign certificate per-host
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[0] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[1] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[2] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[3] ).once
      #stop puppet agent on all hosts
      expect( subject ).to receive( :stop_agent_on ).with( hosts[0] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[1] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[2] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[3] ).once
      # We wait for puppetdb to restart 3 times; once before the first puppet run, and then during each puppet run
      expect( subject ).to receive( :sleep_until_puppetdb_started ).with( hosts[0] ).exactly(3).times
      #run each puppet agent (also captures the final run below)
      expect( subject ).to receive( :on ).with( hosts[0], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      expect( subject ).to receive( :on ).with( hosts[1], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      expect( subject ).to receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      expect( subject ).to receive( :on ).with( hosts[3], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      #run rake task on dashboard

      expect( subject ).to receive( :on ).with( hosts[0], /\/opt\/puppet\/bin\/rake -sf \/opt\/puppet\/share\/puppet-dashboard\/Rakefile .* RAILS_ENV=production/ ).once
      #wait for all hosts to appear in the dashboard
      #run puppet agent now that installation is complete
      # This is captured above (run each puppet agent)

      hosts.each do |host|
        allow( host ).to receive( :tmpdir )
        allow( subject ).to receive( :configure_type_defaults_on ).with( host )
      end

      subject.do_install( hosts, opts )
    end

    it 'can perform a masterless installation' do
      hosts = make_hosts({
        :pe_ver => '3.0',
        :roles => ['agent']
      }, 1)
      opts[:masterless] = true

      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :max_version ).with(['3.0'], '3.8').and_return('3.0')

      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      expect( subject ).to_not receive( :sign_certificate_for )
      expect( subject ).to receive( :stop_agent_on ).with( hosts[0] ).once
      expect( subject ).to_not receive( :sleep_until_puppetdb_started )
      expect( subject ).to_not receive( :wait_for_host_in_dashboard )
      expect( subject ).to_not receive( :on ).with( hosts[0], /puppet agent -t/, :acceptable_exit_codes => [0,2] )

      hosts.each do |host|
        allow( host ).to receive( :tmpdir )
        allow( subject ).to receive( :configure_type_defaults_on ).with( host )
      end

      subject.do_install( hosts, opts)
    end

    it 'can perform a 4+ installation using AIO agents' do
      hosts = make_hosts({
        :pe_ver => '4.0',
        :roles => ['agent'],
      }, 3)
      hosts[0][:roles] = ['master', 'database', 'dashboard']
      hosts[1][:platform] = 'windows'
      hosts[2][:platform] = Beaker::Platform.new('el-6-x86_64')

      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :options ).and_return(Beaker::Options::Presets.new.presets)
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :sign_certificate_for ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :sleep_until_puppetdb_started ).and_return( true )
      allow( subject ).to receive( :max_version ).with(anything, '3.8').and_return('4.0')
      allow( subject ).to receive( :wait_for_host_in_dashboard ).and_return( true )
      allow( subject ).to receive( :puppet_agent ) do |arg|
        "puppet agent #{arg}"
      end
      allow( subject ).to receive( :puppet ) do |arg|
        "puppet #{arg}"
      end

      pa_version = 'rarified_air_9364'
      allow( subject ).to receive( :get_puppet_agent_version ).and_return( pa_version )

      allow( subject ).to receive( :hosts ).and_return( hosts )
      #create answers file per-host, except windows
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      #run installer on all hosts
      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :install_puppet_agent_pe_promoted_repo_on ).with(
        hosts[1],
        {
          :puppet_agent_version => pa_version,
          :puppet_agent_sha => nil,
          :pe_ver => hosts[1][:pe_ver],
          :puppet_collection => nil
        }
      ).once
      expect( subject ).to receive( :install_puppet_agent_pe_promoted_repo_on ).with(
        hosts[2],
        {
          :puppet_agent_version => pa_version,
          :puppet_agent_sha => nil,
          :pe_ver => hosts[2][:pe_ver],
          :puppet_collection => nil
        }
      ).once
      hosts.each do |host|
        expect( subject ).to receive( :configure_type_defaults_on ).with( host ).once
        expect( subject ).to receive( :sign_certificate_for ).with( host ).once
        expect( subject ).to receive( :stop_agent_on ).with( host ).once
        # Each puppet agent runs twice, once for the initial run, and once to configure mcollective
        expect( subject ).to receive( :on ).with( host, /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      end
      # We wait for puppetdb to restart 3 times; once before the first puppet run, and then during each puppet run
      expect( subject ).to receive( :sleep_until_puppetdb_started ).with( hosts[0] ).exactly(3).times
      #wait for all hosts to appear in the dashboard
      #run puppet agent now that installation is complete
      # tested above in the hosts loop ^^

      hosts.each do |host|
        allow( host ).to receive( :tmpdir )
        allow( subject ).to receive( :configure_type_defaults_on ).with( host )
      end

      subject.do_install( hosts, opts )
    end

    it 'can perform a 4/3 mixed installation with AIO and -non agents' do
      hosts = make_hosts({
                           :pe_ver => '4.0',
                           :roles => ['agent'],
                         }, 3)
      hosts[0][:roles] = ['master', 'database', 'dashboard']
      hosts[1][:platform] = 'windows'
      hosts[2][:platform] = Beaker::Platform.new('el-6-x86_64')
      hosts[2][:pe_ver]   = '3.8'

      pa_version = 'rarified_air_1675'
      allow( subject ).to receive( :get_puppet_agent_version ).and_return( pa_version )

      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :options ).and_return(Beaker::Options::Presets.new.presets)
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :sign_certificate_for ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :sleep_until_puppetdb_started ).and_return( true )
      allow( subject ).to receive( :max_version ).with(anything, '3.8').and_return('4.0')
      allow( subject ).to receive( :wait_for_host_in_dashboard ).and_return( true )
      allow( subject ).to receive( :puppet_agent ) do |arg|
        "puppet agent #{arg}"
      end
      allow( subject ).to receive( :puppet ) do |arg|
        "puppet #{arg}"
      end

      allow( subject ).to receive( :hosts ).and_return( hosts )
      #create answers file per-host, except windows
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      #run installer on all hosts
      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :install_puppet_agent_pe_promoted_repo_on ).with(
        hosts[1],
        {
          :puppet_agent_version => pa_version,
          :puppet_agent_sha => nil,
          :pe_ver => hosts[1][:pe_ver],
          :puppet_collection => nil
        }
      ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet-enterprise-installer/ ).once
      hosts.each do |host|
        expect( subject ).to receive( :configure_type_defaults_on ).with( host ).once
        expect( subject ).to receive( :sign_certificate_for ).with( host ).once
        expect( subject ).to receive( :stop_agent_on ).with( host ).once
        # Each puppet agent runs twice, once for the initial run, and once to configure mcollective
        expect( subject ).to receive( :on ).with( host, /puppet agent -t/, :acceptable_exit_codes => [0,2] ).twice
      end
      #  We wait for puppetdb to restart 3 times; once before the first puppet run, and then during each puppet run
      expect( subject ).to receive( :sleep_until_puppetdb_started ).with( hosts[0] ).exactly(3).times
      #wait for all hosts to appear in the dashboard
      #run puppet agent now that installation is complete
      # tested above in the hosts loop ^^

      hosts.each do |host|
        allow( host ).to receive( :tmpdir )
        allow( subject ).to receive( :configure_type_defaults_on ).with( host )
      end

      subject.do_install( hosts, opts )
    end

    it 'sets puppet-agent acceptable_exit_codes correctly for config helper on upgrade' do
      hosts = make_hosts({
        :previous_pe_ver => '3.0',
        :pe_ver => '4.0',
        :pe_upgrade_ver => '4.0',
        :roles => ['agent'],
      }, 2)
      hosts[0][:roles] = ['master', 'database', 'dashboard']
      hosts[1][:platform] = Beaker::Platform.new('el-6-x86_64')
      opts[:HOSTS] = {}
      hosts.each do |host|
        opts[:HOSTS][host.name] = host
      end

      pa_version = 'rarified_air_75699'
      allow( subject ).to receive( :get_puppet_agent_version ).and_return( pa_version )

      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :options ).and_return(Beaker::Options::Presets.new.presets)
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :sign_certificate_for ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :sleep_until_puppetdb_started ).and_return( true )
      allow( subject ).to receive( :max_version ).with(anything, '3.8').and_return('4.0')
      allow( subject ).to receive( :wait_for_host_in_dashboard ).and_return( true )
      allow( subject ).to receive( :puppet_agent ) do |arg|
        "puppet agent #{arg}"
      end
      allow( subject ).to receive( :puppet ) do |arg|
        "puppet #{arg}"
      end

      allow( subject ).to receive( :hosts ).and_return( hosts )
      #create answers file per-host, except windows
      allow( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ )
      #run installer on all hosts
      allow( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ )
      allow( subject ).to receive(
        :install_puppet_agent_pe_promoted_repo_on
      ).with( hosts[1], {
        :puppet_agent_version => pa_version,
        :puppet_agent_sha     => nil,
        :pe_ver               => hosts[1][:pe_ver],
        :puppet_collection    => nil
      } )
      # expect( subject ).to receive( :on ).with( hosts[2], /puppet-enterprise-installer/ ).once
      hosts.each do |host|
        allow( subject ).to receive( :add_pe_defaults_on ).with( host ) unless subject.aio_version?(host)
        allow( subject ).to receive( :sign_certificate_for ).with( host )
        allow( subject ).to receive( :stop_agent_on ).with( host )
        # Each puppet agent runs twice, once for the initial run, and once to configure mcollective
        allow( subject ).to receive( :on ).with( host, /puppet agent -t/, :acceptable_exit_codes => [0,2] )
      end
      #  We wait for puppetdb to restart 3 times; once before the first puppet run, and then during each puppet run
      allow( subject ).to receive( :sleep_until_puppetdb_started ).with( hosts[0] ).exactly(3).times
      #run puppet agent now that installation is complete
      allow( subject ).to receive( :on ).with( hosts, /puppet agent/, :acceptable_exit_codes => [0,2] ).twice

      opts[:type] = :upgrade
      expect( subject ).to receive( :setup_defaults_and_config_helper_on ).with( hosts[1], hosts[0], [0, 1, 2] )

      hosts.each do |host|
        allow( host ).to receive( :tmpdir )
        allow( subject ).to receive( :configure_type_defaults_on ).with( host )
      end

      subject.do_install( hosts, opts )
    end

  end

  describe 'do_higgs_install' do

    before :each do
      my_time = double( "time double" )
      allow( my_time ).to receive( :strftime ).and_return( "2014-07-01_15.27.53" )
      allow( Time ).to receive( :new ).and_return( my_time )

      hosts[0]['working_dir'] = "tmp/2014-07-01_15.27.53"
      hosts[0]['dist'] = 'dist'
      hosts[0]['pe_installer'] = 'pe-installer'
      allow( hosts[0] ).to receive( :tmpdir ).and_return( "/tmp/2014-07-01_15.27.53" )

      @fail_result = Beaker::Result.new( {}, '' )
      @fail_result.stdout = "No match here"
      @success_result = Beaker::Result.new( {}, '' )
      @success_result.stdout = "Please go to https://website in your browser to continue installation"
    end

    it 'can perform a simple installation' do
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :sleep ).and_return( true )

      allow( subject ).to receive( :hosts ).and_return( hosts )

      #run higgs installer command
      expect( subject ).to receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      expect( subject ).to receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :accept_all_exit_codes => true }).and_return( @fail_result, @success_result )
      subject.do_higgs_install( hosts[0], opts )
    end

    it 'fails out after checking installation log 10 times' do
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :sleep ).and_return( true )

      allow( subject ).to receive( :hosts ).and_return( hosts )

      #run higgs installer command
      expect( subject ).to receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      expect( subject ).to receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :accept_all_exit_codes => true }).exactly(10).times.and_return( @fail_result )
      expect{ subject.do_higgs_install( hosts[0], opts ) }.to raise_error RuntimeError, "Failed to kick off PE (Higgs) web installation"
    end

  end

  describe 'install_pe' do

    it 'calls do_install with sorted hosts' do
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      allow( subject ).to receive( :do_install ).and_return( true )
      expect( subject ).to receive( :do_install ).with( hosts, {} )
      subject.install_pe
    end

    it 'fills in missing pe_ver' do
      hosts.each do |h|
        h['pe_ver'] = nil
      end
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :do_install ).and_return( true )
      expect( subject ).to receive( :do_install ).with( hosts, {} )
      subject.install_pe
      hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end

    it 'can act upon a single host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :sorted_hosts ).and_return( [hosts[0]] )
      expect( subject ).to receive( :do_install ).with( [hosts[0]], {} )
      subject.install_pe_on(hosts[0], {})
    end
  end

  describe 'install_higgs' do
    it 'fills in missing pe_ver' do
      hosts[0]['pe_ver'] = nil
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( subject ).to receive( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :do_higgs_install ).and_return( true )
      expect( subject ).to receive( :do_higgs_install ).with( hosts[0], {} )
      subject.install_higgs
      expect( hosts[0]['pe_ver'] ).to be === '2.8'
    end

  end

  describe 'upgrade_pe' do

    it 'calls puppet-enterprise-upgrader for pre 3.0 upgrades' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be === 'puppet-enterprise-upgrader'
      end
    end

    it 'uses standard upgrader for post 3.0 upgrades' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '3.1' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '3.1' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be nil
      end
    end

    it 'updates pe_ver post upgrade' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end

    it 'can act upon a single host' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '3.1' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '3.1' )
      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :sorted_hosts ).and_return( [hosts[0]] )
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( [hosts[0]], {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe_on(hosts[0], {}, path)
    end

    it 'sets previous_pe_ver' do
      subject.hosts = hosts
      host = hosts[0]
      host['pe_ver'] = '3.8.5'
      host['pe_upgrade_ver'] = '2016.2.0'
      expect(subject).to receive(:do_install).with([host], Hash)
      subject.upgrade_pe_on([host], {})
      expect(host['pe_ver']).to eq('2016.2.0')
      expect(host['previous_pe_ver']).to eq('3.8.5')
    end
  end

  describe 'fetch_and_push_pe' do

    it 'fetches the file' do
      allow( subject ).to receive( :scp_to )

      path = 'abcde/fg/hij'
      filename = 'pants'
      extension = '.txt'
      expect( subject ).to receive( :fetch_http_file ).with( path, "#{filename}#{extension}", 'tmp/pe' )
      subject.fetch_and_push_pe(unixhost, path, filename, extension)
    end

    it 'allows you to set the local copy dir' do
      allow( subject ).to receive( :scp_to )

      path = 'defg/hi/j'
      filename = 'pants'
      extension = '.txt'
      local_dir = '/root/domes'
      expect( subject ).to receive( :fetch_http_file ).with( path, "#{filename}#{extension}", local_dir )
      subject.fetch_and_push_pe(unixhost, path, filename, extension, local_dir)
    end

    it 'scp\'s to the host' do
      allow( subject ).to receive( :fetch_http_file )

      path = 'abcde/fg/hij'
      filename = 'pants'
      extension = '.txt'
      expect( subject ).to receive( :scp_to ).with( unixhost, "tmp/pe/#{filename}#{extension}", unixhost['working_dir'] )
      subject.fetch_and_push_pe(unixhost, path, filename, extension)
    end

  end

  describe 'create_agent_specified_arrays' do
    let(:master)        { make_host( 'master',       { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['master', 'agent']})}
    let(:db)            { make_host( 'db',           { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['database', 'agent']})}
    let(:console)       { make_host( 'console',      { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['dashboard', 'agent']})}
    let(:monolith)      { make_host( 'monolith',     { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => %w(master dashboard database)})}
    let(:frictionless)  { make_host( 'frictionless', { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['agent', 'frictionless']})}
    let(:agent1)        { make_host( 'agent1',       { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['agent']})}
    let(:agent2)        { make_host( 'agent2',       { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['agent']})}
    let(:default_agent) { make_host( 'default',      { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['default', 'agent']})}
    let(:masterless)    { make_host( 'masterless',   { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['agent', 'masterless']})}
    let(:compiler)      { make_host( 'compiler',     { :platform => 'linux',
                                                       :pe_ver   => '4.0',
                                                       :roles => ['agent', 'compile_master']})}

    it 'sorts hosts with common PE roles' do
      these_hosts = [master, db, console, agent1, frictionless]
      agent_only, non_agent = subject.create_agent_specified_arrays(these_hosts)
      expect(agent_only.length).to be 1
      expect(agent_only).to include(agent1)
      expect(non_agent.length).to be 4
      expect(non_agent).to include(master)
      expect(non_agent).to include(db)
      expect(non_agent).to include(console)
      expect(non_agent).to include(frictionless)
    end

    # Possibly needed for NetDev and Scale testing
    it 'defaults to classifying custom roles as "agent only"' do
      these_hosts = [monolith, compiler, agent1, agent2]
      agent_only, non_agent = subject.create_agent_specified_arrays(these_hosts)
      expect(agent_only.length).to be 3
      expect(agent_only).to include(agent1)
      expect(agent_only).to include(agent2)
      expect(agent_only).to include(compiler)
      expect(non_agent.length).to be 1
      expect(non_agent).to include(monolith)
    end

    # Most common form of module testing
    it 'allows a puppet-agent host to be the default test target' do
      these_hosts = [monolith, default_agent]
      agent_only, non_agent = subject.create_agent_specified_arrays(these_hosts)
      expect(agent_only.length).to be 1
      expect(agent_only).to include(default_agent)
      expect(non_agent.length).to be 1
      expect(non_agent).to include(monolith)
    end

    # Preferred module on commit scenario
    it 'handles masterless scenarios' do
      these_hosts = [masterless]
      agent_only, non_agent = subject.create_agent_specified_arrays(these_hosts)
      expect(agent_only.length).to be 1
      expect(non_agent).to be_empty
    end

    # IIRC, this is the basic PE integration smoke test
    it 'handles agent-only-less scenarios' do
      these_hosts = [monolith, frictionless]
      agent_only, non_agent = subject.create_agent_specified_arrays(these_hosts)
      expect(agent_only).to be_empty
      expect(non_agent.length).to be 2
    end
  end

  describe '#check_console_status_endpoint' do

    it 'does not do anything if version is less than 2015.2.0' do
      allow(subject).to receive(:version_is_less).and_return(true)

      global_options = subject.instance_variable_get(:@options)
      expect(global_options).not_to receive(:[]).with(:pe_console_status_attempts)
      subject.check_console_status_endpoint({})
    end

    it 'allows the number of attempts to be configured via the global options' do
      attempts = 37819
      options = {:pe_console_status_attempts => attempts}
      allow(subject).to receive(:options).and_return(options)
      allow(subject).to receive(:version_is_less).and_return(false)
      allow(subject).to receive(:fail_test)

      expect(subject).to receive(:repeat_fibonacci_style_for).with(attempts)
      subject.check_console_status_endpoint({})
    end

    it 'yields false to repeat_fibonacci_style_for when conditions are not true' do
      allow(subject).to receive(:options).and_return({})
      allow(subject).to receive(:version_is_less).and_return(false)
      allow(subject).to receive(:sleep)

      output_hash = {
        'classifier-service' => {}
      }
      output_stub = Object.new
      allow(output_stub).to receive(:stdout)
      expect(subject).to receive(:on).exactly(9).times.and_return(output_stub)
      allow(JSON).to receive(:parse).and_return(output_hash)
      allow(subject).to receive(:fail_test)
      subject.check_console_status_endpoint({})
    end

    it 'yields false to repeat_fibonacci_style_for when JSON::ParserError occurs' do
      allow(subject).to receive(:options).and_return({})
      allow(subject).to receive(:version_is_less).and_return(false)
      allow(subject).to receive(:sleep)

      output_stub = Object.new
      # empty string causes JSON::ParserError
      allow(output_stub).to receive(:stdout).and_return('')
      expect(subject).to receive(:on).exactly(9).times.and_return(output_stub)
      allow(subject).to receive(:fail_test)
      subject.check_console_status_endpoint({})
    end

    it 'calls fail_test when no checks pass' do
      allow(subject).to receive(:options).and_return({})
      allow(subject).to receive(:version_is_less).and_return(false)

      allow(subject).to receive(:repeat_fibonacci_style_for).and_return(false)
      expect(subject).to receive(:fail_test)
      subject.check_console_status_endpoint({})
    end
  end

  describe '#get_puppet_agent_version' do

    context 'when the puppet_agent version is set on an argument' do

      it 'uses host setting over all others' do
        pa_version = 'pants of the dance'
        host_arg = { :puppet_agent_version => pa_version }
        local_options = { :puppet_agent_version => 'something else' }
        expect( subject.get_puppet_agent_version( host_arg, local_options ) ).to be === pa_version
      end

      it 'uses local options over all others (except host setting)' do
        pa_version = 'who did it?'
        local_options = { :puppet_agent_version => pa_version }
        expect( subject.get_puppet_agent_version( {}, local_options ) ).to be === pa_version
      end
    end

    context 'when the puppet_agent version has to be read dynamically' do

      def test_setup(mock_values={})
        json_hash    = mock_values[:json_hash]
        pa_version   = mock_values[:pa_version]
        pa_version ||= 'pa_version_' + rand(10 ** 5).to_s.rjust(5,'0') # 5 digit random number string
        json_hash  ||= "{ \"values\": { \"aio_agent_version\": \"#{pa_version}\" }}"

        allow( subject ).to receive( :master ).and_return( {} )
        result_mock = Object.new
        allow( result_mock ).to receive( :stdout ).and_return( json_hash )
        allow( result_mock ).to receive( :exit_code ).and_return( 0 )
        allow( subject ).to receive( :on ).and_return( result_mock )
        pa_version
      end

      it 'parses and returns the command output correctly' do
        pa_version = test_setup
        expect( subject.get_puppet_agent_version( {} ) ).to be === pa_version
      end

      it 'saves the puppet_agent version in the local_options argument' do
        pa_version = test_setup
        local_options_hash = {}
        subject.get_puppet_agent_version( {}, local_options_hash )
        expect( local_options_hash[:puppet_agent_version] ).to be === pa_version
      end

    end

    context 'failures' do

      def test_setup(mock_values)
        exit_code   = mock_values[:exit_code] || 0
        json_hash   = mock_values[:json_hash]
        pa_version  = 'pa_version_'
        pa_version << rand(10 ** 5).to_s.rjust(5,'0') # 5 digit random number string
        json_hash ||= "{ \"values\": { \"aio_agent_build\": \"#{pa_version}\" }}"

        allow( subject ).to receive( :master ).and_return( {} )
        result_mock = Object.new
        allow( result_mock ).to receive( :stdout ).and_return( json_hash )
        allow( result_mock ).to receive( :exit_code ).and_return( exit_code )
        allow( subject ).to receive( :on ).and_return( result_mock )
      end

      it 'fails if "puppet facts" does not succeed' do
        test_setup( :exit_code => 1 )
        expect { subject.get_puppet_agent_version( {} ) }.to raise_error( ArgumentError )
      end

      it 'fails if neither fact exists' do
        test_setup( :json_hash => "{ \"values\": {}}" )
        expect { subject.get_puppet_agent_version( {} ) }.to raise_error( ArgumentError )
      end
    end
  end

  describe 'get_console_dispatcher_for_beaker_pe' do
    it { expect(subject.get_console_dispatcher_for_beaker_pe).to be_nil }
    it do
      expect { subject.get_console_dispatcher_for_beaker_pe(true) }.to(
        raise_exception(LoadError, /cannot load.*scooter/)
      )
    end
    it do
      expect { subject.get_console_dispatcher_for_beaker_pe! }.to(
        raise_exception(LoadError, /cannot load.*scooter/)
      )
    end
  end

  def assert_meep_conf_edit(input, output, path, &test)
    # mock reading pe.conf
    expect(master).to receive(:exec).with(
      have_attributes(:command => match(%r{cat #{path}})),
      anything
    ).and_return(
      double('result', :stdout => input)
    )

    # mock writing pe.conf and check for parameters
    expect(subject).to receive(:create_remote_file).with(
      master,
      path,
      output
    )

    yield
  end

  describe 'configure_puppet_agent_service' do
    let(:pe_version) { '2017.1.0' }
    let(:master) { hosts[0] }

    before(:each) do
      hosts.each { |h| h[:pe_ver] = pe_version }
      allow( subject ).to receive( :hosts ).and_return( hosts )
    end

    it 'requires parameters' do
      expect { subject.configure_puppet_agent_service }.to raise_error(ArgumentError, /wrong number/)
    end

    context 'master prior to 2017.1.0' do
      let(:pe_version) { '2016.5.1' }

      it 'raises an exception about version' do
        expect { subject.configure_puppet_agent_service({}) }.to(
          raise_error(StandardError, /Can only manage.*2017.1.0; tried.* 2016.5.1/)
        )
      end
    end

    context '2017.1.0 master' do
      let(:pe_conf_path) { '/etc/puppetlabs/enterprise/conf.d/pe.conf' }
      let(:pe_conf) do
        <<-EOF
"node_roles": {
  "pe_role::monolithic::primary_master": ["#{master.name}"],
}
        EOF
      end
      let(:gold_pe_conf) do
        <<-EOF
"node_roles": {
  "pe_role::monolithic::primary_master": ["#{master.name}"],
}
"pe_infrastructure::agent::puppet_service_managed": true
"pe_infrastructure::agent::puppet_service_ensure": "stopped"
"pe_infrastructure::agent::puppet_service_enabled": false
        EOF
      end

      it "modifies the agent puppet service settings in pe.conf" do
        # mock hitting the console
        dispatcher = double('dispatcher').as_null_object
        expect(subject).to receive(:get_console_dispatcher_for_beaker_pe)
          .and_return(dispatcher)

        assert_meep_conf_edit(pe_conf, gold_pe_conf, pe_conf_path) do
          subject.configure_puppet_agent_service(:ensure => 'stopped', :enabled => false)
        end
      end
    end
  end

  describe 'update_pe_conf' do
    let(:pe_version) { '2017.1.0' }
    let(:master) { hosts[0] }

    before(:each) do
      hosts.each { |h| h[:pe_ver] = pe_version }
      allow( subject ).to receive( :hosts ).and_return( hosts )
    end

    it 'requires parameters' do
      expect { subject.update_pe_conf}.to raise_error(ArgumentError, /wrong number/)
    end

    context '2017.1.0 master' do
      let(:pe_conf_path) { '/etc/puppetlabs/enterprise/conf.d/pe.conf' }
      let(:pe_conf) do
        <<-EOF
"node_roles": {
  "pe_role::monolithic::primary_master": ["#{master.name}"],
}
"namespace::removed": "bye"
"namespace::changed": "old"
        EOF
      end
      let(:gold_pe_conf) do
        <<-EOF
"node_roles": {
  "pe_role::monolithic::primary_master": ["#{master.name}"],
}

"namespace::changed": "new"
"namespace::add": "hi"
"namespace::add2": "other"
        EOF
      end

      it "adds, changes and removes hocon parameters from pe.conf" do
        assert_meep_conf_edit(pe_conf, gold_pe_conf, pe_conf_path) do
          subject.update_pe_conf(
            {
              "namespace::add"     => "hi",
              "namespace::changed" => "new",
              "namespace::removed" => nil,
              "namespace::add2"     => "other",
            }
          )
        end
      end
    end
  end

  describe 'create_or_update_node_conf' do
    let(:pe_version) { '2017.1.0' }
    let(:master) { hosts[0] }
    let(:node) { hosts[1] }
    let(:node_conf_path) { "/etc/puppetlabs/enterprise/conf.d/nodes/vm2.conf" }
    let(:node_conf) do
      <<-EOF
"namespace::removed": "bye"
"namespace::changed": "old"
      EOF
    end
    let(:updated_node_conf) do
      <<-EOF

"namespace::changed": "new"
"namespace::add": "hi"
      EOF
    end
    let(:created_node_conf) do
      <<-EOF
{
  "namespace::one": "red"
  "namespace::two": "blue"
}
      EOF
    end

    before(:each) do
      hosts.each { |h| h[:pe_ver] = pe_version }
      allow( subject ).to receive( :hosts ).and_return( hosts )
    end

    it 'requires parameters' do
      expect { subject.update_pe_conf}.to raise_error(ArgumentError, /wrong number/)
    end

    it 'creates a node file that did not exist' do
      expect(master).to receive(:file_exist?).with(node_conf_path).and_return(false)
      expect(master).to receive(:file_exist?).with("/etc/puppetlabs/enterprise/conf.d/nodes").and_return(false)
      expect(subject).to receive(:create_remote_file).with(master, node_conf_path, %Q|{\n}\n|)

      assert_meep_conf_edit(%Q|{\n}\n|, created_node_conf, node_conf_path) do
        subject.create_or_update_node_conf(
          node,
          {
            "namespace::one" => "red",
            "namespace::two" => "blue",
          },
        )
      end
    end

    it 'updates a node file that did exist' do
      assert_meep_conf_edit(node_conf, updated_node_conf, node_conf_path) do
        subject.create_or_update_node_conf(
          node,
          {
            "namespace::add"     => "hi",
            "namespace::changed" => "new",
            "namespace::removed" => nil,
          },
        )
      end
    end
  end

  describe "get_unwrapped_pe_conf_value" do
    let(:pe_version) { '2017.1.0' }
    let(:master) { hosts[0] }
    let(:pe_conf_path) { "/etc/puppetlabs/enterprise/conf.d/pe.conf" }
    let(:pe_conf) do
      <<-EOF
"namespace::bool": true
"namespace::string": "stringy"
"namespace::array": ["of", "things"]
"namespace::hash": {
  "foo": "a"
  "bar": "b"
}
      EOF
    end

    before(:each) do
      hosts.each { |h| h[:pe_ver] = pe_version }
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect(master).to receive(:exec).with(
        have_attributes(:command => match(%r{cat #{pe_conf_path}})),
        anything
      ).and_return(
        double('result', :stdout => pe_conf)
      )
    end

    it { expect(subject.get_unwrapped_pe_conf_value("namespace::bool")).to eq(true) }
    it { expect(subject.get_unwrapped_pe_conf_value("namespace::string")).to eq("stringy") }
    it { expect(subject.get_unwrapped_pe_conf_value("namespace::array")).to eq(["of","things"]) }
    it do
      expect(subject.get_unwrapped_pe_conf_value("namespace::hash")).to eq({
        'foo' => 'a',
        'bar' => 'b',
      })
    end
  end
end
