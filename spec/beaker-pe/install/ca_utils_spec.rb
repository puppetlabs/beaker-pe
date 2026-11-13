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

  # Helpers shared by the external PKI specs below.
  def pem_blocks(pem, kind)
    pem.scan(/-----BEGIN #{kind}-----.*?-----END #{kind}-----/m)
  end

  def certs_in(pem)
    pem_blocks(pem, 'CERTIFICATE').map { |p| OpenSSL::X509::Certificate.new(p) }
  end

  def crls_in(pem)
    pem_blocks(pem, 'X509 CRL').map { |p| OpenSSL::X509::CRL.new(p) }
  end

  def ext_of(cert, oid)
    cert.extensions.find { |e| e.oid == oid }
  end

  def crl_number(crl)
    crl.extensions.find { |e| e.oid == 'crlNumber' }.value.to_i
  end

  def ski_of(cert)
    ext_of(cert, 'subjectKeyIdentifier').value
  end

  def aki_of(cert)
    ext_of(cert, 'authorityKeyIdentifier').value.sub(/\Akeyid:/, '').lines.first.strip
  end

  describe 'create_chained_pki (unchanged behaviour)' do
    before(:each) do
      allow(subject).to receive(:create_chained_pki).and_call_original
    end

    it 'keeps the signer CN as intermediate-ca, unconstrained, for verify_intermediate_ca.rb' do
      pki = subject.create_chained_pki
      expect(pki[:int_cert].subject.to_s).to eq('/CN=intermediate-ca')
      expect(pki[:root_cert].subject.to_s).to eq('/CN=root-ca')
      basic = ext_of(pki[:int_cert], 'basicConstraints')
      expect(basic.value).to eq('CA:TRUE')
      expect(basic).to be_critical
    end

    it 'encodes the CSR as PKCS#10 v1 (version 0) so OpenSSL 3 accepts it' do
      csr = subject.create_csr(subject.create_private_key, '/CN=csr-version')
      expect(csr.version).to eq(0)
      expect(csr.verify(csr.public_key)).to be true
    end

    it 'still produces a verifiable chain with CRLs and the original keyUsage' do
      pki = subject.create_chained_pki
      expect(pki[:root_cert].verify(pki[:root_cert].public_key)).to be true
      expect(pki[:int_cert].verify(pki[:root_cert].public_key)).to be true
      expect(ext_of(pki[:int_cert], 'keyUsage').value).to eq('Certificate Sign, CRL Sign')
      crls = crls_in(pki[:int_crl_chain])
      expect(crls.map { |c| c.issuer.to_s }).to eq(['/CN=intermediate-ca', '/CN=root-ca'])
      expect(crls.first.verify(pki[:int_cert].public_key)).to be true
      expect(crls.last.verify(pki[:root_cert].public_key)).to be true
    end

    it 'keeps the five year validity on certificates' do
      pki = subject.create_chained_pki
      lifetime = pki[:int_cert].not_after - pki[:int_cert].not_before
      expect(lifetime).to be_within(2).of(Beaker::DSL::InstallUtils::CAUtils::FIVE_YEARS)
    end
  end

  describe 'create_external_pki' do
    it 'rejects fewer than one level' do
      expect { subject.create_external_pki(levels: 0) }.to raise_error(ArgumentError, /levels/)
    end

    it 'rejects a path_lens array whose length does not match levels' do
      expect { subject.create_external_pki(levels: 2, path_lens: [1]) }.to raise_error(ArgumentError, /path_lens/)
    end

    it 'rejects a path_lens that is not an Array' do
      expect { subject.create_external_pki(levels: 1, path_lens: 1) }.to raise_error(ArgumentError, /path_lens/)
    end

    it 'rejects a negative or non-Integer pathlen' do
      expect { subject.create_external_pki(levels: 1, path_lens: [-1]) }.to raise_error(ArgumentError, /path_len/)
      expect { subject.create_external_pki(levels: 1, path_lens: [1.5]) }.to raise_error(ArgumentError, /path_len/)
      expect { subject.create_external_pki(levels: 1, path_lens: ['1']) }.to raise_error(ArgumentError, /path_len/)
    end

    it 'rejects constraint keys that are not levels instead of ignoring them' do
      expect { subject.create_external_pki(levels: 2, name_constraints: { 5 => 'permitted;DNS:example.com' }) }
        .to raise_error(ArgumentError, /name_constraints.*\[5\]/)
      expect { subject.create_external_pki(levels: 2, policy_constraints: { '1' => 'requireExplicitPolicy:0' }) }
        .to raise_error(ArgumentError, /policy_constraints.*"1"/)
      expect { subject.create_external_pki(levels: 2, eku: { 2 => 'serverAuth' }) }
        .to raise_error(ArgumentError, /eku/)
    end

    it 'rejects a constraint argument that is not a Hash' do
      expect { subject.create_external_pki(levels: 1, eku: []) }.to raise_error(ArgumentError, /eku must be a Hash/)
    end

    it 'returns a PKI whose level list cannot be modified' do
      expect(subject.create_external_pki(levels: 2).levels).to be_frozen
    end

    it 'defaults every level to an unconstrained pathlen' do
      pki = subject.create_external_pki(levels: 2)
      pki.levels.each do |level|
        basic = ext_of(level.cert, 'basicConstraints')
        expect(basic).to be_critical
        expect(basic.value).to eq('CA:TRUE')
      end
    end

    it 'makes the root self-signed and each intermediate issued by the level above' do
      pki = subject.create_external_pki(levels: 3)
      root, int1, int2 = pki.levels
      expect(root.cert.issuer.to_s).to eq(root.cert.subject.to_s)
      expect(int1.cert.issuer.to_s).to eq(root.cert.subject.to_s)
      expect(int2.cert.issuer.to_s).to eq(int1.cert.subject.to_s)
      expect(pki.levels.map { |l| l.cert.subject.to_s }.uniq.length).to eq(3)
    end

    it 'encodes pathlen 0, 1 and nil as asked on each level, always critical' do
      pki = subject.create_external_pki(levels: 3, path_lens: [nil, 1, 0])
      values = pki.levels.map { |l| ext_of(l.cert, 'basicConstraints') }
      expect(values.map(&:critical?)).to eq([true, true, true])
      expect(values.map(&:value)).to eq(['CA:TRUE', 'CA:TRUE, pathlen:1', 'CA:TRUE, pathlen:0'])
    end

    it 'sets keyUsage keyCertSign and cRLSign on every level' do
      pki = subject.create_external_pki(levels: 2)
      pki.levels.each do |level|
        usage = ext_of(level.cert, 'keyUsage')
        expect(usage).to be_critical
        expect(usage.value).to eq('Certificate Sign, CRL Sign')
      end
    end

    it 'adds nameConstraints and policyConstraints only on the requested level' do
      pki = subject.create_external_pki(
        levels: 3,
        name_constraints: { 1 => 'permitted;DNS:example.com' },
        policy_constraints: { 2 => 'requireExplicitPolicy:0' }
      )
      oids = pki.levels.map { |l| l.cert.extensions.map(&:oid) }
      expect(oids.map { |o| o.include?('nameConstraints') }).to eq([false, true, false])
      expect(oids.map { |o| o.include?('policyConstraints') }).to eq([false, false, true])
      expect(ext_of(pki.levels[1].cert, 'nameConstraints').value).to match(/example\.com/)
      expect(ext_of(pki.levels[1].cert, 'nameConstraints')).to be_critical
      expect(ext_of(pki.levels[2].cert, 'policyConstraints').value).to match(/Require Explicit Policy:0/)
      expect(ext_of(pki.levels[2].cert, 'policyConstraints')).to be_critical
    end

    it 'adds extendedKeyUsage only on the requested level' do
      pki = subject.create_external_pki(levels: 2, eku: { 1 => 'serverAuth' })
      expect(ext_of(pki.levels[0].cert, 'extendedKeyUsage')).to be_nil
      expect(ext_of(pki.levels[1].cert, 'extendedKeyUsage').value).to match(/TLS Web Server Authentication/)
    end

    it 'gives every level a CRL that verifies against its own issuer' do
      pki = subject.create_external_pki(levels: 3)
      pki.levels.each do |level|
        expect(level.crl.issuer.to_s).to eq(level.cert.subject.to_s)
        expect(level.crl.verify(level.key)).to be true
        expect(level.crl.verify(level.cert.public_key)).to be true
      end
    end

    it 'orders bundle issuing CA first and root last' do
      pki = subject.create_external_pki(levels: 3)
      bundle = certs_in(pki.bundle)
      expect(bundle.map { |c| c.subject.to_s }).to eq(pki.levels.reverse.map { |l| l.cert.subject.to_s })
      expect(bundle.last.issuer.to_s).to eq(bundle.last.subject.to_s)
    end

    it 'orders crl_chain issuing CA first and root last' do
      pki = subject.create_external_pki(levels: 3)
      crls = crls_in(pki.crl_chain)
      expect(crls.map { |c| c.issuer.to_s }).to eq(pki.levels.reverse.map { |l| l.cert.subject.to_s })
    end

    it 'exposes root and issuing level conveniences' do
      pki = subject.create_external_pki(levels: 3)
      expect(pki.root).to equal(pki.levels.first)
      expect(pki.issuing).to equal(pki.levels.last)
    end
  end

  describe 'signing_ca_on' do
    let(:host) { make_host('unixhost', { :platform => 'linux' }) }
    let(:targetdir) { '/tmp/external_ca' }
    let(:written) { {} }
    let(:pki) { subject.create_external_pki(levels: 2, path_lens: [nil, 1]) }

    before(:each) do
      allow(subject).to receive(:on)
      allow(subject).to receive(:create_remote_file) do |_host, path, content, *|
        written[path] = content
      end
    end

    it 'requires signer_path_len to be given explicitly' do
      expect { subject.signing_ca_on(host, pki, targetdir: targetdir) }.to raise_error(ArgumentError, /signer_path_len/)
    end

    it 'creates the target directory mode 700 and restricts the private key to mode 600' do
      expect(subject).to receive(:on).with(host, "mkdir -p #{targetdir} && chmod 700 #{targetdir}", :acceptable_exit_codes => [0]).ordered
      expect(subject).to receive(:on).with(host, "chmod 600 #{targetdir}/int_key", :acceptable_exit_codes => [0]).ordered
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
    end

    it 'shell-escapes the target directory' do
      expect(subject).to receive(:on).with(host, 'mkdir -p /tmp/a\\ b && chmod 700 /tmp/a\\ b', :acceptable_exit_codes => [0])
      expect(subject).to receive(:on).with(host, 'chmod 600 /tmp/a\\ b/int_key', :acceptable_exit_codes => [0])
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: '/tmp/a b')
    end

    it 'rejects a negative signer_path_len' do
      expect { subject.signing_ca_on(host, pki, signer_path_len: -1, targetdir: targetdir) }
        .to raise_error(ArgumentError, /path_len/)
    end

    it 'creates the target directory and returns the paths setup/intermediate_ca.rb uses' do
      files = subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      expect(files).to eq(
        :root_cert => "#{targetdir}/root_cert",
        :int_cert => "#{targetdir}/int_cert",
        :int_ca_bundle => "#{targetdir}/int_ca_bundle",
        :int_key => "#{targetdir}/int_key",
        :int_crl_chain => "#{targetdir}/int_crl_chain"
      )
      expect(written.keys).to match_array(files.values)
    end

    it 'mints a signer named intermediate-ca under the issuing CA' do
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
      expect(signer.subject.to_s).to eq('/CN=intermediate-ca')
      expect(signer.issuer.to_s).to eq(pki.issuing.cert.subject.to_s)
      expect(signer.verify(pki.issuing.cert.public_key)).to be true
    end

    [[1, 'CA:TRUE, pathlen:1'], [0, 'CA:TRUE, pathlen:0'], [nil, 'CA:TRUE']].each do |len, expected|
      it "encodes signer_path_len #{len.inspect} as #{expected.inspect}" do
        subject.signing_ca_on(host, pki, signer_path_len: len, targetdir: targetdir)
        signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
        basic = ext_of(signer, 'basicConstraints')
        expect(basic).to be_critical
        expect(basic.value).to eq(expected)
      end
    end

    it 'writes a bundle with the signer first and the PKI bundle after it' do
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      bundle = certs_in(written["#{targetdir}/int_ca_bundle"])
      expect(bundle.map { |c| c.subject.to_s }).to eq(['/CN=intermediate-ca'] + certs_in(pki.bundle).map { |c| c.subject.to_s })
    end

    it 'writes a crl chain with the signer CRL first, verified by the signer key' do
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
      crls = crls_in(written["#{targetdir}/int_crl_chain"])
      expect(crls.map { |c| c.issuer.to_s }).to eq(['/CN=intermediate-ca'] + crls_in(pki.crl_chain).map { |c| c.issuer.to_s })
      expect(crls.first.verify(signer.public_key)).to be true
    end

    it 'writes the signer private key matching the signer certificate' do
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
      key = OpenSSL::PKey::RSA.new(written["#{targetdir}/int_key"])
      expect(signer.check_private_key(key)).to be true
    end

    it 'produces a chain that verifies a leaf issued by the signer (3-level PKI, signer pathlen 1)' do
      subject.signing_ca_on(host, pki, signer_path_len: 1, targetdir: targetdir)
      signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
      key = OpenSSL::PKey::RSA.new(written["#{targetdir}/int_key"])
      leaf_key = subject.create_private_key
      leaf = subject.sign(key, signer, subject.create_csr(leaf_key, '/CN=leaf'))

      store = OpenSSL::X509::Store.new
      store.add_cert(pki.root.cert)
      expect(store.verify(leaf, [signer, pki.issuing.cert])).to be true
    end

    it 'chain verification fails when the issuing CA pathlen 0 forbids the signer CA below it' do
      tight = subject.create_external_pki(levels: 2, path_lens: [nil, 0])
      subject.signing_ca_on(host, tight, signer_path_len: 0, targetdir: targetdir)
      signer = OpenSSL::X509::Certificate.new(written["#{targetdir}/int_cert"])
      key = OpenSSL::PKey::RSA.new(written["#{targetdir}/int_key"])
      leaf = subject.sign(key, signer, subject.create_csr(subject.create_private_key, '/CN=leaf'))

      store = OpenSSL::X509::Store.new
      store.add_cert(tight.root.cert)
      expect(store.verify(leaf, [signer, tight.issuing.cert])).to be false
      expect(store.error).to eq(OpenSSL::X509::V_ERR_PATH_LENGTH_EXCEEDED)
    end
  end

  describe 'single_tier_ca' do
    it 'returns a self-signed CA whose CRL verifies' do
      pki = subject.single_tier_ca('single-tier')
      expect(pki.levels.length).to eq(1)
      cert = pki.root.cert
      expect(cert.subject.to_s).to eq('/CN=single-tier')
      expect(cert.issuer.to_s).to eq(cert.subject.to_s)
      expect(cert.verify(cert.public_key)).to be true
      expect(ext_of(cert, 'basicConstraints').value).to eq('CA:TRUE')
      expect(pki.root.crl.verify(pki.root.key)).to be true
    end

    it 'has the root as the whole bundle and crl chain' do
      pki = subject.single_tier_ca('single-tier')
      expect(certs_in(pki.bundle).map(&:to_der)).to eq([pki.root.cert.to_der])
      expect(crls_in(pki.crl_chain).map(&:to_der)).to eq([pki.root.crl.to_der])
    end

    it 'rejects an empty name' do
      expect { subject.single_tier_ca('') }.to raise_error(ArgumentError, /name/)
      expect { subject.single_tier_ca(nil) }.to raise_error(ArgumentError, /name/)
    end

    it 'accepts a full DN as the name' do
      pki = subject.single_tier_ca('/O=Example/CN=other-ca')
      expect(pki.root.cert.subject.to_s).to eq('/O=Example/CN=other-ca')
    end
  end

  describe 'cross_sign_csr' do
    let(:pki) { subject.create_external_pki(levels: 2, path_lens: [nil, 2]) }
    let(:csr_key) { subject.create_private_key }
    let(:csr) { subject.create_csr(csr_key, '/CN=pe-signer') }

    it 'keeps the CSR subject and public key and takes the issuer DN' do
      cert = subject.cross_sign_csr(pki, csr.to_pem, level: 1, validity: 86_400, path_len: 1)
      expect(cert.subject.to_s).to eq('/CN=pe-signer')
      expect(cert.public_key.to_der).to eq(csr_key.public_key.to_der)
      expect(cert.issuer.to_s).to eq(pki.levels[1].cert.subject.to_s)
      expect(cert.verify(pki.levels[1].cert.public_key)).to be true
    end

    it 'sets the AKI to the issuer SKI' do
      cert = subject.cross_sign_csr(pki, csr.to_pem, level: 1, validity: 86_400, path_len: 1)
      expect(aki_of(cert)).to eq(ski_of(pki.levels[1].cert))
    end

    it 'applies the requested pathlen as a critical CA basicConstraints' do
      [[1, 'CA:TRUE, pathlen:1'], [0, 'CA:TRUE, pathlen:0'], [nil, 'CA:TRUE']].each do |len, expected|
        cert = subject.cross_sign_csr(pki, csr.to_pem, level: 1, validity: 86_400, path_len: len)
        basic = ext_of(cert, 'basicConstraints')
        expect(basic).to be_critical
        expect(basic.value).to eq(expected)
      end
    end

    it 'applies the requested validity' do
      cert = subject.cross_sign_csr(pki, csr.to_pem, level: 0, validity: 3_600, path_len: nil)
      expect(cert.not_after - cert.not_before).to be_within(2).of(3_600)
    end

    it 'can sign under the root level' do
      cert = subject.cross_sign_csr(pki, csr.to_pem, level: 0, validity: 3_600, path_len: nil)
      expect(cert.issuer.to_s).to eq(pki.root.cert.subject.to_s)
    end

    it 'accepts an OpenSSL CSR object as well as PEM' do
      cert = subject.cross_sign_csr(pki, csr, level: 1, validity: 3_600, path_len: nil)
      expect(cert.subject.to_s).to eq('/CN=pe-signer')
    end

    it 'refuses a CSR whose signature does not verify' do
      other = subject.create_private_key
      bad = OpenSSL::X509::Request.new
      bad.public_key = other.public_key
      bad.subject = OpenSSL::X509::Name.parse('/CN=forged')
      bad.version = 0
      bad.sign(csr_key, Beaker::DSL::InstallUtils::CAUtils::DEFAULT_SIGNING_DIGEST)
      expect { subject.cross_sign_csr(pki, bad.to_pem, level: 1, validity: 3_600, path_len: nil) }
        .to raise_error(ArgumentError, /signature/)
    end

    it 'refuses a validity that is not Numeric seconds' do
      expect { subject.cross_sign_csr(pki, csr.to_pem, level: 1, validity: '3600', path_len: nil) }
        .to raise_error(ArgumentError, /validity/)
    end

    it 'refuses an invalid path_len' do
      expect { subject.cross_sign_csr(pki, csr.to_pem, level: 1, validity: 3_600, path_len: -2) }
        .to raise_error(ArgumentError, /path_len/)
    end

    it 'refuses a level outside the PKI' do
      expect { subject.cross_sign_csr(pki, csr.to_pem, level: 5, validity: 3_600, path_len: nil) }
        .to raise_error(ArgumentError, /level/)
    end
  end

  describe 'reissue_same_key' do
    let(:pki) { subject.create_external_pki(levels: 2, path_lens: [nil, 2]) }
    let(:csr_key) { subject.create_private_key }
    let(:original) do
      subject.cross_sign_csr(pki, subject.create_csr(csr_key, '/CN=pe-signer').to_pem,
                             level: 1, validity: 3_600, path_len: 1)
    end

    it 'keeps subject, key and SKI and gets a new serial' do
      renewed = subject.reissue_same_key(pki, original, issuer_level: 1, validity: 7_200)
      expect(renewed.subject.to_s).to eq(original.subject.to_s)
      expect(renewed.public_key.to_der).to eq(original.public_key.to_der)
      expect(ski_of(renewed)).to eq(ski_of(original))
      expect(renewed.serial).not_to eq(original.serial)
    end

    it 'is signed by the issuer level and carries its AKI' do
      renewed = subject.reissue_same_key(pki, original, issuer_level: 1, validity: 7_200)
      expect(renewed.issuer.to_s).to eq(pki.levels[1].cert.subject.to_s)
      expect(renewed.verify(pki.levels[1].cert.public_key)).to be true
      expect(aki_of(renewed)).to eq(ski_of(pki.levels[1].cert))
    end

    it 'keeps the original basicConstraints and keyUsage' do
      renewed = subject.reissue_same_key(pki, original, issuer_level: 1, validity: 7_200)
      expect(ext_of(renewed, 'basicConstraints').value).to eq('CA:TRUE, pathlen:1')
      expect(ext_of(renewed, 'basicConstraints')).to be_critical
      expect(ext_of(renewed, 'keyUsage').value).to eq(ext_of(original, 'keyUsage').value)
    end

    it 'applies the new validity' do
      renewed = subject.reissue_same_key(pki, original, issuer_level: 1, validity: 7_200)
      expect(renewed.not_after - renewed.not_before).to be_within(2).of(7_200)
    end

    it 'can reissue the self-signed root under the root level' do
      renewed = subject.reissue_same_key(pki, pki.root.cert, issuer_level: 0, validity: 7_200)
      expect(renewed.subject.to_s).to eq(pki.root.cert.subject.to_s)
      expect(renewed.issuer.to_s).to eq(renewed.subject.to_s)
      expect(renewed.verify(pki.root.cert.public_key)).to be true
      expect(renewed.serial).not_to eq(pki.root.cert.serial)
    end

    it 'refuses a validity that is not Numeric seconds' do
      expect { subject.reissue_same_key(pki, original, issuer_level: 1, validity: nil) }
        .to raise_error(ArgumentError, /validity/)
    end

    it 'can reissue under a different issuer level than the original' do
      renewed = subject.reissue_same_key(pki, original, issuer_level: 0, validity: 7_200)
      expect(renewed.issuer.to_s).to eq(pki.root.cert.subject.to_s)
      expect(aki_of(renewed)).to eq(ski_of(pki.root.cert))
    end
  end

  describe 'revoke_in_pki' do
    let(:pki) { subject.create_external_pki(levels: 3) }

    it 'adds the serial to the level CRL and raises the CRL number' do
      before_number = crl_number(pki.levels[1].crl)
      crl = subject.revoke_in_pki(pki, level: 1, serial: 4242)
      expect(crl.revoked.map { |r| r.serial.to_i }).to eq([4242])
      expect(crl_number(crl)).to eq(before_number + 1)
      expect(pki.levels[1].crl).to equal(crl)
    end

    it 'leaves the other levels CRLs alone' do
      others = [0, 2].map { |i| pki.levels[i].crl.to_der }
      subject.revoke_in_pki(pki, level: 1, serial: 4242)
      expect([0, 2].map { |i| pki.levels[i].crl.to_der }).to eq(others)
    end

    it 'signs the CRL with the level key and republishes it in crl_chain' do
      subject.revoke_in_pki(pki, level: 1, serial: 4242)
      expect(pki.levels[1].crl.verify(pki.levels[1].cert.public_key)).to be true
      chain = crls_in(pki.crl_chain)
      expect(chain.map { |c| c.revoked.length }).to eq([0, 1, 0])
    end

    it 'accumulates multiple revocations and bumps the number each time' do
      subject.revoke_in_pki(pki, level: 1, serial: 1)
      crl = subject.revoke_in_pki(pki, level: 1, serial: 2)
      expect(crl.revoked.map { |r| r.serial.to_i }).to eq([1, 2])
      expect(crl_number(crl)).to eq(2)
    end

    it 'refuses a level outside the PKI' do
      expect { subject.revoke_in_pki(pki, level: 9, serial: 1) }.to raise_error(ArgumentError, /level/)
    end
  end

  describe 'refresh_crl' do
    let(:pki) { subject.create_external_pki(levels: 2) }

    it 'yields an expired CRL for a past next_update, with a raised CRL number' do
      before_number = crl_number(pki.levels[1].crl)
      crl = subject.refresh_crl(pki, level: 1, next_update: Time.now - 3_600)
      expect(crl.next_update).to be < Time.now
      expect(crl.last_update).to be < crl.next_update
      expect(crl_number(crl)).to eq(before_number + 1)
      expect(crl.verify(pki.levels[1].cert.public_key)).to be true
    end

    it 'yields a short-lived CRL for a near next_update' do
      crl = subject.refresh_crl(pki, level: 1, next_update: Time.now + 120)
      expect(crl.next_update - Time.now).to be_within(5).of(120)
      expect(crl.last_update).to be <= Time.now
    end

    it 'preserves existing revocations' do
      subject.revoke_in_pki(pki, level: 1, serial: 77)
      crl = subject.refresh_crl(pki, level: 1, next_update: Time.now + 3_600)
      expect(crl.revoked.map { |r| r.serial.to_i }).to eq([77])
    end

    it 'republishes the refreshed CRL in crl_chain' do
      crl = subject.refresh_crl(pki, level: 1, next_update: Time.now - 3_600)
      expect(crls_in(pki.crl_chain).first.to_der).to eq(crl.to_der)
    end

    it 'refuses a next_update that is not a Time' do
      expect { subject.refresh_crl(pki, level: 1, next_update: 3600) }.to raise_error(ArgumentError, /next_update/)
    end

    it 'puts lastUpdate an hour before a next_update that is not after now' do
      next_update = Time.now
      crl = subject.refresh_crl(pki, level: 1, next_update: next_update)
      expect(crl.last_update).to be_within(2).of(next_update - 3_600)
      expect(crl.last_update).to be < crl.next_update
    end

    it 'puts lastUpdate one second before now for a next_update after now' do
      crl = subject.refresh_crl(pki, level: 1, next_update: Time.now + 3_600)
      expect(crl.last_update).to be_within(3).of(Time.now - 1)
    end

    it 'stays expired when revoke_in_pki later re-signs the CRL' do
      subject.refresh_crl(pki, level: 1, next_update: Time.now - 3_600)
      crl = subject.revoke_in_pki(pki, level: 1, serial: 5)
      expect(crl.next_update).to be < Time.now
      expect(crl.revoked.map { |r| r.serial.to_i }).to eq([5])
    end

    it 'refuses a level outside the PKI' do
      expect { subject.refresh_crl(pki, level: 4, next_update: Time.now) }.to raise_error(ArgumentError, /level/)
    end
  end

  describe 'revoke_in_pki aliasing' do
    it 'leaves a previously obtained CRL object unmodified' do
      pki = subject.create_external_pki(levels: 2)
      old = pki.levels[1].crl
      subject.revoke_in_pki(pki, level: 1, serial: 99)
      expect(old.revoked).to be_empty
      expect(crl_number(old)).to eq(0)
      expect(pki.levels[1].crl).not_to equal(old)
    end
  end

  describe 'an external PKI under OpenSSL::X509::Store with CRL checking' do
    let(:pki) { subject.create_external_pki(levels: 3, path_lens: [nil, 1, 0]) }
    let(:leaf) do
      issuing = pki.issuing
      subject.sign(issuing.key, issuing.cert, subject.create_csr(subject.create_private_key, '/CN=leaf'))
    end
    let(:intermediates) { [pki.levels[2].cert, pki.levels[1].cert] }

    def store_for(pki)
      store = OpenSSL::X509::Store.new
      store.add_cert(pki.root.cert)
      store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK | OpenSSL::X509::V_FLAG_CRL_CHECK_ALL
      pki.levels.each { |level| store.add_crl(level.crl) }
      store
    end

    it 'verifies a leaf through root, pathlen 1 intermediate and pathlen 0 issuing CA' do
      expect(store_for(pki).verify(leaf, intermediates)).to be true
    end

    it 'rejects the leaf once revoke_in_pki publishes its serial at the issuing level' do
      subject.revoke_in_pki(pki, level: 2, serial: leaf.serial)
      store = store_for(pki)
      expect(store.verify(leaf, intermediates)).to be false
      expect(store.error).to eq(OpenSSL::X509::V_ERR_CERT_REVOKED)
    end

    it 'rejects the chain when an upstream CA is revoked at the level above it' do
      subject.revoke_in_pki(pki, level: 1, serial: pki.levels[2].cert.serial)
      store = store_for(pki)
      expect(store.verify(leaf, intermediates)).to be false
      expect(store.error).to eq(OpenSSL::X509::V_ERR_CERT_REVOKED)
    end

    it 'rejects the leaf when the issuing CA CRL has expired via refresh_crl' do
      subject.refresh_crl(pki, level: 2, next_update: Time.now - 3_600)
      store = store_for(pki)
      expect(store.verify(leaf, intermediates)).to be false
      expect(store.error).to eq(OpenSSL::X509::V_ERR_CRL_HAS_EXPIRED)
    end

    it 'accepts the leaf again after refresh_crl re-issues a valid CRL' do
      subject.refresh_crl(pki, level: 2, next_update: Time.now - 3_600)
      subject.refresh_crl(pki, level: 2, next_update: Time.now + 3_600)
      expect(store_for(pki).verify(leaf, intermediates)).to be true
    end
  end
end
