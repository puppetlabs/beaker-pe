require 'spec_helper'

describe Beaker::DSL::InstallUtils::FeatureFlags do
  let(:options) do
    opts= Beaker::Options::Presets.new
    opts.presets.merge(opts.env_vars)
  end
  let(:flags) { Beaker::DSL::InstallUtils::FeatureFlags.new(options) }
  let(:answers) do
    {
      'answers' => {
         'feature_flags' => feature_flags
      }
    }
  end
  let(:feature_flags) { {} }
  let(:feature_flags) do
    {
      'pe_modules_next' => flag
    }
  end
  let(:environment_flag_key) { "PE_MODULES_NEXT" }
  let(:environment_flag_value) {}

  context 'neither answers nor env' do
    it { expect(flags.send(:answers)).to eq(StringifyHash.new) }
    it { expect(flags.send(:answers?)).to eq(false) }
    it { expect(flags.send(:flags)).to eq(StringifyHash.new) }
    it { expect(flags.send(:flags?)).to eq(false) }
    it { expect(flags.flag?('foo')).to be_nil }
    it { expect(flags.flag?(:pe_modules_next)).to be_nil }
    it { expect(flags.flag?('pe_modules_next')).to be_nil }
  end

  context 'answers' do
    let(:flag) {}

    before(:each) do
      options.merge!(answers)
    end

    it { expect(flags.flag?('pe_modules_next')).to be_nil }

    context 'with flag' do
      context 'true' do
        let(:flag) { true }
        it { expect(flags.flag?('pe_modules_next')).to eq(true) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(true) }
      end

      context 'true as a string' do
        let(:flag) { 'true' }
        it { expect(flags.flag?('pe_modules_next')).to eq(true) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(true) }
      end

      context 'false' do
        let(:flag) { false }
        it { expect(flags.flag?('pe_modules_next')).to eq(false) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(false) }
      end

      context 'false as a string' do
        let(:flag) { 'false' }
        it { expect(flags.flag?('pe_modules_next')).to eq(false) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(false) }
      end
    end
  end

  context 'env' do
    before(:each) do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:include?).and_call_original
      expect(ENV).to receive(:[]).with(environment_flag_key).and_return(environment_flag_value)
      expect(ENV).to receive(:include?).with(environment_flag_key).and_return(true)
    end

    it { expect(flags.flag?(:pe_modules_next)).to eq(nil) }

    context 'with flag' do
      context 'true' do
        let(:environment_flag_value) { 'true' }
        it { expect(flags.flag?('pe_modules_next')).to eq(true) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(true) }
      end

      context 'false' do
        let(:environment_flag_value) { 'false' }
        it { expect(flags.flag?('pe_modules_next')).to eq(false) }
        it { expect(flags.flag?(:pe_modules_next)).to eq(false) }
      end
    end
  end

  context 'answers and env' do
    before(:each) do
      options.merge!(answers)
      allow(ENV).to receive(:include?).and_call_original
      expect(ENV).to_not receive(:include?).with('pe_modules_next')
      expect(ENV).to_not receive(:include?).with('PE_MODULES_NEXT')
    end

    context 'answers true and env false' do
      let(:flag) { 'true' }

      it { expect(flags.flag?(:pe_modules_next)).to eq(true) }
    end

    context 'answers false and env true' do
      let(:flag) { 'false' }

      it { expect(flags.flag?(:pe_modules_next)).to eq(false) }
    end
  end

  context 'registering flags' do
    it do
      expect(flags.register_flags!).to eq(options)
      expect(options[:answers]).to be_nil
    end

    context 'with env variables' do
      before(:each) do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:include?).and_call_original
        expect(ENV).to receive(:include?).with('pe_modules_next').and_return(true)
      end

      it 'picks up a true flag from environment' do
        expect(ENV).to receive(:[]).with('pe_modules_next').and_return('true')

        flags.register_flags!
        expect(options[:answers]).to match(
          :feature_flags => {
            :pe_modules_next => true
          }
        )
      end

      it 'picks up a false flag from environment' do
        expect(ENV).to receive(:[]).with('pe_modules_next').and_return('false')

        flags.register_flags!
        expect(options[:answers]).to match(
          :feature_flags => {
            :pe_modules_next => false
          }
        )
      end
    end

    context 'with answers and env variables' do
      let(:flag) { false }

      before(:each) do
        answers['answers'][:some_other_answer] = 'value'
        options.merge!(answers)
        allow(ENV).to receive(:include?).and_call_original
        expect(ENV).to_not receive(:include?).with('pe_modules_next')
      end

      it do
        flags.register_flags!
        expect(options[:answers]).to match(
          :some_other_answer => 'value',
          :feature_flags => {
            :pe_modules_next => false
          },
        )
      end
    end
  end
end
