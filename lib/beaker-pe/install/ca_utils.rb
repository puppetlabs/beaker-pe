#Much of this is taken from PuppetSpec:SSL
require "openssl"
require "securerandom"
require "shellwords"

module Beaker
  module DSL
    module InstallUtils
      module CAUtils
        PRIVATE_KEY_LENGTH = 2048
        FIVE_YEARS = 5 * 365 * 24 * 60 * 60
        CA_EXTENSIONS = [
        ["basicConstraints", "CA:TRUE", true],
        ["keyUsage", "keyCertSign, cRLSign", true],
        ["subjectKeyIdentifier", "hash", false],
        ["authorityKeyIdentifier", "keyid:always", false]
        ]
        NODE_EXTENSIONS = [
        ["keyUsage", "digitalSignature", true],
        ["subjectKeyIdentifier", "hash", false]
        ]
        DEFAULT_SIGNING_DIGEST = OpenSSL::Digest::SHA256.new
        DEFAULT_REVOCATION_REASON = OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE
        ROOT_CA_NAME = "/CN=root-ca"
        INT_CA_NAME = "/CN=intermediate-ca"
        EXPLANATORY_TEXT = <<-EOT
# Root Issuer: #{ROOT_CA_NAME}
# Intermediate Issuer: #{INT_CA_NAME}
EOT

        # One CA in an external PKI built by create_external_pki / single_tier_ca.
        # revoke_in_pki and refresh_crl each store a new CRL object in crl; a CRL
        # object obtained earlier is never modified.
        PkiLevel = Struct.new(:name, :key, :cert, :crl)

        # An external PKI, root first. bundle and crl_chain are always built from
        # the current levels, issuing CA first and root last, which is the order
        # pe_install::signing_ca and `puppetserver ca import` expect. Unlike the
        # module-level bundle(*items), they are bare concatenated PEM with no
        # explanatory header comments.
        ExternalPki = Struct.new(:levels) do
          def root
            levels.first
          end

          def issuing
            levels.last
          end

          def bundle
            levels.reverse.map { |level| level.cert.to_pem }.join
          end

          def crl_chain
            levels.reverse.map { |level| level.crl.to_pem }.join
          end
        end

        # Generate CA bundle with root and intermediate certs, as well as CRL chain and private key for
        # the intermediate CA, pushed to the host for use during PE install with pe_install::signing_ca
        #
        # @param [Host] host  The host to create CA bundle files on.  Defaults to global 'master' object.
        # @param [String] targetdir  Location to save files on host, to be referenced in pe.conf for install.
        # @return [Hash] File names => where they were put on the host
        # TODO PE-48617 targetdir is not shell-escaped and int_key is written with the remote umask; signing_ca_on shows the hardened form.
        def generate_ca_bundle_on(host = master, targetdir = '/tmp/ca_bundle')
          files = {}
          pki = create_chained_pki
          on(host, "mkdir -p #{targetdir}", :acceptable_exit_codes => [0])
          pki.each do |name,cert|
            create_remote_file(host, "#{targetdir}/#{name}", cert.to_s, :acceptable_exit_codes => [0])
            files["#{name}".to_sym] = "#{targetdir}/#{name}"
          end
          files
        end

        def create_private_key(length = PRIVATE_KEY_LENGTH)
          OpenSSL::PKey::RSA.new(length)
        end

        def self_signed_ca(key, name, extensions = CA_EXTENSIONS)
          cert = OpenSSL::X509::Certificate.new

          cert.public_key = key.public_key
          cert.subject = OpenSSL::X509::Name.parse(name)
          cert.issuer = cert.subject
          cert.version = 2
          cert.serial = rand(2**128)

          not_before = just_now
          cert.not_before = not_before
          cert.not_after = not_before + FIVE_YEARS

          ext_factory = extension_factory_for(cert, cert)
          extensions.each do |ext|
            extension = ext_factory.create_extension(*ext)
            cert.add_extension(extension)
          end

          cert.sign(key, DEFAULT_SIGNING_DIGEST)

          cert
        end

        def create_csr(key, name)
          csr = OpenSSL::X509::Request.new

          csr.public_key = key.public_key
          csr.subject = OpenSSL::X509::Name.parse(name)
          # PKCS#10 v1 is encoded as 0; OpenSSL 3 rejects the former value of 2.
          csr.version = 0
          csr.sign(key, DEFAULT_SIGNING_DIGEST)

          csr
        end

        def sign(ca_key, ca_cert, csr, extensions = NODE_EXTENSIONS, validity = FIVE_YEARS)
          cert = OpenSSL::X509::Certificate.new

          cert.public_key = csr.public_key
          cert.subject = csr.subject
          cert.issuer = ca_cert.subject
          cert.version = 2
          cert.serial = rand(2**128)

          not_before = just_now
          cert.not_before = not_before
          cert.not_after = not_before + validity

          ext_factory = extension_factory_for(ca_cert, cert)
          extensions.each do |ext|
            extension = ext_factory.create_extension(*ext)
            cert.add_extension(extension)
          end

          cert.sign(ca_key, DEFAULT_SIGNING_DIGEST)

          cert
        end

        def create_crl_for(ca_cert, ca_key)
          crl = OpenSSL::X509::CRL.new
          crl.version = 1
          crl.issuer = ca_cert.subject

          ef = extension_factory_for(ca_cert)
          crl.add_extension(
            ef.create_extension(["authorityKeyIdentifier", "keyid:always", false]))
          crl.add_extension(
            OpenSSL::X509::Extension.new("crlNumber", OpenSSL::ASN1::Integer(0)))

          not_before = just_now
          crl.last_update = not_before
          crl.next_update = not_before + FIVE_YEARS
          crl.sign(ca_key, DEFAULT_SIGNING_DIGEST)

          crl
        end

        def revoke(serial, crl, ca_key)
          revoked = OpenSSL::X509::Revoked.new
          revoked.serial = serial
          revoked.time = Time.now
          revoked.add_extension(
            OpenSSL::X509::Extension.new("CRLReason",
                                        OpenSSL::ASN1::Enumerated(DEFAULT_REVOCATION_REASON)))

          crl.add_revoked(revoked)
          extensions = crl.extensions.group_by{|e| e.oid == 'crlNumber' }
          crl_number = extensions[true].first
          unchanged_exts = extensions[false]

          next_crl_number = crl_number.value.to_i + 1
          new_crl_number_ext = OpenSSL::X509::Extension.new("crlNumber",
                                                            OpenSSL::ASN1::Integer(next_crl_number))

          crl.extensions = unchanged_exts + [new_crl_number_ext]
          crl.sign(ca_key, DEFAULT_SIGNING_DIGEST)

          crl
        end

        def create_chained_pki
          root_key = create_private_key
          root_cert = self_signed_ca(root_key, ROOT_CA_NAME)
          root_crl = create_crl_for(root_cert, root_key)

          int_key = create_private_key
          int_csr = create_csr(int_key, INT_CA_NAME)
          int_cert = sign(root_key, root_cert, int_csr, CA_EXTENSIONS)
          int_crl = create_crl_for(int_cert, int_key)

          int_ca_bundle = bundle(int_cert, root_cert)
          int_crl_chain = bundle(int_crl, root_crl)

          {
              :root_cert => root_cert,
              :int_cert => int_cert,
              :int_ca_bundle => int_ca_bundle,
              :int_key  => int_key,
              :int_crl_chain => int_crl_chain,
          }
        end

        # Mint an external PKI on the test runner: a self-signed root plus
        # levels - 1 intermediates, each with its own CRL.
        #
        # Levels are numbered from 0 (root) to levels - 1 (the issuing CA), the
        # same numbering the other helpers take as `level:`.
        #
        # @param [Integer] levels  Total CA levels, root included (>= 1).
        # @param [Array<Integer,nil>] path_lens  pathLenConstraint per level, root first;
        #   nil entries (and the default) leave that level unconstrained.
        # @param [Hash{Integer=>String}] name_constraints  level => nameConstraints value,
        #   e.g. 'permitted;DNS:example.com'. Added as a critical extension.
        # @param [Hash{Integer=>String}] policy_constraints  level => policyConstraints value,
        #   e.g. 'requireExplicitPolicy:0'. Added as a critical extension.
        # @param [Hash{Integer=>String}] eku  level => extendedKeyUsage value, e.g. 'serverAuth'.
        # @return [ExternalPki] CAs are named /CN=external-root-ca-<id> and
        #   /CN=external-int-ca-<level>-<id>, where <id> is random per call so two
        #   PKIs on one runner are very unlikely to share a DN.
        # @raise [ArgumentError] if levels is not an Integer >= 1, path_lens is not an
        #   Array with one entry per level, a path_lens entry is not nil or a
        #   non-negative Integer, or a constraint Hash has a key that is not a level.
        def create_external_pki(levels:, path_lens: nil, name_constraints: {}, policy_constraints: {}, eku: {})
          unless levels.is_a?(Integer) && levels >= 1
            raise ArgumentError, "levels must be an Integer >= 1, got #{levels.inspect}"
          end
          path_lens = Array.new(levels) if path_lens.nil?
          unless path_lens.is_a?(Array) && path_lens.length == levels
            raise ArgumentError, "path_lens needs an Array with one entry per level (#{levels}), got #{path_lens.inspect}"
          end
          name_constraints ||= {}
          policy_constraints ||= {}
          eku ||= {}
          { 'name_constraints' => name_constraints,
            'policy_constraints' => policy_constraints,
            'eku' => eku }.each do |arg, per_level|
            raise ArgumentError, "#{arg} must be a Hash of level => value, got #{per_level.inspect}" unless per_level.is_a?(Hash)

            bad = per_level.keys.reject { |k| k.is_a?(Integer) && k >= 0 && k < levels }
            unless bad.empty?
              raise ArgumentError, "#{arg} has keys outside the levels 0..#{levels - 1}: #{bad.inspect}"
            end
          end

          id = SecureRandom.hex(3)
          chain = []
          levels.times do |i|
            name = i.zero? ? "/CN=external-root-ca-#{id}" : "/CN=external-int-ca-#{i}-#{id}"
            extensions = ca_extensions_for(path_lens[i],
                                           name_constraints: name_constraints[i],
                                           policy_constraints: policy_constraints[i],
                                           eku: eku[i])
            key = create_private_key
            cert = if i.zero?
                     self_signed_ca(key, name, extensions)
                   else
                     parent = chain.last
                     sign(parent.key, parent.cert, create_csr(key, name), extensions)
                   end
            chain << PkiLevel.new(name, key, cert, create_crl_for(cert, key))
          end

          ExternalPki.new(chain.freeze)
        end

        # A self-signed CA with its CRL, for single-tier fixtures (root = signer).
        #
        # @param [String] name  A CN, or a full DN starting with '/'.
        # @return [ExternalPki] with exactly one level
        # @raise [ArgumentError] if name is empty
        def single_tier_ca(name)
          name = name.to_s
          raise ArgumentError, 'name must not be empty' if name.empty?

          dn = name.start_with?('/') ? name : "/CN=#{name}"
          key = create_private_key
          cert = self_signed_ca(key, dn)
          ExternalPki.new([PkiLevel.new(dn, key, cert, create_crl_for(cert, key))].freeze)
        end

        # Mint a PE signing CA under the PKI's issuing CA (the last level, pki.issuing)
        # and push the files PE needs (pe_install::signing_ca / `puppetserver ca import`)
        # to the host. The directory is created mode 700 and the private key mode 600.
        #
        # @param [Host] host  Host to write the files on.
        # @param [ExternalPki] pki  The PKI whose issuing CA signs the signer.
        # @param [Integer,nil] signer_path_len  Required. pathLenConstraint on the signer:
        #   nil leaves it unconstrained (the shape create_chained_pki produces), 0 forbids
        #   any CA below the signer, 1 allows one more CA level below it.
        # @param [String] targetdir  Directory on host to write into.
        # @param [String] signer_name  Signer DN. Defaults to INT_CA_NAME, keeping the
        #   /CN=intermediate-ca that generate_ca_bundle_on's signer has, for acceptance
        #   checks that match on that name.
        # @return [Hash] same keys as generate_ca_bundle_on => paths on the host. The bundle
        #   and CRL chain files are plain PEM, without generate_ca_bundle_on's explanatory
        #   header comments.
        def signing_ca_on(host, pki, signer_path_len:, targetdir: '/tmp/ca_bundle', signer_name: INT_CA_NAME)
          issuer = pki.issuing
          key = create_private_key
          cert = sign(issuer.key, issuer.cert, create_csr(key, signer_name),
                      ca_extensions_for(signer_path_len))
          crl = create_crl_for(cert, key)

          contents = {
            :root_cert => pki.root.cert.to_pem,
            :int_cert => cert.to_pem,
            :int_ca_bundle => cert.to_pem + pki.bundle,
            :int_key => key.to_pem,
            :int_crl_chain => crl.to_pem + pki.crl_chain,
          }

          dir = Shellwords.escape(targetdir)
          on(host, "mkdir -p #{dir} && chmod 700 #{dir}", :acceptable_exit_codes => [0])
          files = {}
          contents.each do |name, pem|
            create_remote_file(host, "#{targetdir}/#{name}", pem, :acceptable_exit_codes => [0])
            files[name] = "#{targetdir}/#{name}"
          end
          on(host, "chmod 600 #{Shellwords.escape(files[:int_key])}", :acceptable_exit_codes => [0])
          files
        end

        # Sign a CSR (for example from `external-ca csr`) as a CA certificate
        # under the given level, keeping the CSR's subject and public key.
        #
        # @param [ExternalPki] pki  The PKI whose level signs the CSR.
        # @param [String,OpenSSL::X509::Request] csr_pem  The CSR, PEM or parsed.
        # @param [Integer] level  Issuing level, 0 = root.
        # @param [Numeric] validity  Lifetime in seconds.
        # @param [Integer,nil] path_len  pathLenConstraint on the new CA, nil for none.
        # @return [OpenSSL::X509::Certificate]
        # @raise [ArgumentError] if level is outside the PKI, validity is not Numeric,
        #   path_len is not nil or a non-negative Integer, or the CSR signature does
        #   not verify.
        def cross_sign_csr(pki, csr_pem, level:, validity:, path_len:)
          issuer = pki_level(pki, level)
          check_validity!(validity)
          csr = csr_pem.is_a?(OpenSSL::X509::Request) ? csr_pem : OpenSSL::X509::Request.new(csr_pem)
          raise ArgumentError, 'CSR signature does not verify' unless csr.verify(csr.public_key)

          sign(issuer.key, issuer.cert, csr, ca_extensions_for(path_len), validity)
        end

        # Re-issue a certificate with the same subject, key and SKI and a new
        # serial, signed by the given level. Extensions other than the AKI are
        # copied from the original.
        #
        # @param [ExternalPki] pki
        # @param [OpenSSL::X509::Certificate] cert  Certificate to renew.
        # @param [Integer] issuer_level  Issuing level, 0 = root.
        # @param [Numeric] validity  Lifetime in seconds. Zero or negative gives an
        #   already-expired certificate, which is useful for expiry scenarios.
        # @return [OpenSSL::X509::Certificate] Signed by issuer_level whether or not
        #   cert was originally issued there.
        # @raise [ArgumentError] if issuer_level is outside the PKI or validity is not Numeric.
        def reissue_same_key(pki, cert, issuer_level:, validity:)
          issuer = pki_level(pki, issuer_level)
          check_validity!(validity)
          renewed = OpenSSL::X509::Certificate.new
          renewed.version = 2
          renewed.serial = rand(2**128)
          renewed.subject = cert.subject
          renewed.issuer = issuer.cert.subject
          renewed.public_key = cert.public_key

          not_before = just_now
          renewed.not_before = not_before
          renewed.not_after = not_before + validity

          cert.extensions.each do |ext|
            renewed.add_extension(ext) unless ext.oid == 'authorityKeyIdentifier'
          end
          aki = extension_factory_for(issuer.cert, renewed)
                .create_extension('authorityKeyIdentifier', 'keyid:always', false)
          renewed.add_extension(aki)

          renewed.sign(issuer.key, DEFAULT_SIGNING_DIGEST)
          renewed
        end

        # Publish an external revocation: add serial to a copy of the level's CRL,
        # bump its CRL number and re-sign it. lastUpdate and nextUpdate are kept, so
        # revoking on a CRL made expired by refresh_crl leaves it expired.
        #
        # @param [ExternalPki] pki
        # @param [Integer] level  Level whose CRL gets the entry, 0 = root.
        # @param [Integer] serial  Serial number of the certificate to revoke.
        # @return [OpenSSL::X509::CRL] the new CRL (also stored on the level)
        # @raise [ArgumentError] if level is outside the PKI
        def revoke_in_pki(pki, level:, serial:)
          target = pki_level(pki, level)
          target.crl = revoke(serial, target.crl.dup, target.key)
        end

        # Re-issue the level's CRL with the given nextUpdate and a bumped CRL
        # number, keeping existing revocations. A nextUpdate in the past yields
        # an expired CRL; one just ahead yields a short-lived CRL.
        #
        # @param [ExternalPki] pki
        # @param [Integer] level  Level whose CRL is re-issued, 0 = root.
        # @param [Time] next_update  The new nextUpdate. If it is not after now,
        #   lastUpdate is set to an hour before it so lastUpdate stays earlier than
        #   nextUpdate; otherwise lastUpdate is one second before now.
        # @return [OpenSSL::X509::CRL] the new CRL (also stored on the level)
        # @raise [ArgumentError] if level is outside the PKI or next_update is not a Time
        def refresh_crl(pki, level:, next_update:)
          target = pki_level(pki, level)
          unless next_update.is_a?(Time)
            raise ArgumentError, "next_update must be a Time, got #{next_update.inspect}"
          end

          old = target.crl

          crl = OpenSSL::X509::CRL.new
          crl.version = 1
          crl.issuer = target.cert.subject
          crl.add_extension(
            extension_factory_for(target.cert).create_extension(["authorityKeyIdentifier", "keyid:always", false]))
          next_number = old.extensions.find { |e| e.oid == 'crlNumber' }.value.to_i + 1
          crl.add_extension(
            OpenSSL::X509::Extension.new("crlNumber", OpenSSL::ASN1::Integer(next_number)))
          old.revoked.each { |entry| crl.add_revoked(entry) }

          last_update = just_now
          last_update = next_update - 3600 if next_update <= last_update + 1
          crl.last_update = last_update
          crl.next_update = next_update
          crl.sign(target.key, DEFAULT_SIGNING_DIGEST)

          target.crl = crl
        end

        # CA_EXTENSIONS with basicConstraints replaced by one carrying the given
        # pathLenConstraint (nil = none, else a non-negative Integer), plus optional
        # nameConstraints and policyConstraints (both critical) and extendedKeyUsage
        # (non-critical). keyUsage, SKI and AKI are kept from CA_EXTENSIONS.
        def ca_extensions_for(path_len, name_constraints: nil, policy_constraints: nil, eku: nil)
          unless path_len.nil? || (path_len.is_a?(Integer) && path_len >= 0)
            raise ArgumentError, "path_len must be nil or a non-negative Integer, got #{path_len.inspect}"
          end

          basic = path_len.nil? ? 'CA:TRUE' : "CA:TRUE,pathlen:#{path_len}"
          extensions = [["basicConstraints", basic, true]] +
                       CA_EXTENSIONS.reject { |ext| ext[0] == "basicConstraints" }
          extensions << ["nameConstraints", name_constraints, true] if name_constraints
          extensions << ["policyConstraints", policy_constraints, true] if policy_constraints
          extensions << ["extendedKeyUsage", eku, false] if eku
          extensions
        end

        def pki_level(pki, level)
          unless level.is_a?(Integer) && level >= 0 && level < pki.levels.length
            raise ArgumentError, "level #{level.inspect} is outside the PKI (0..#{pki.levels.length - 1})"
          end

          pki.levels[level]
        end

        def check_validity!(validity)
          return if validity.is_a?(Numeric)

          raise ArgumentError, "validity must be Numeric seconds, got #{validity.inspect}"
        end

        def just_now
          Time.now - 1
        end

        def extension_factory_for(ca, cert = nil)
          ef = OpenSSL::X509::ExtensionFactory.new
          ef.issuer_certificate  = ca
          ef.subject_certificate = cert if cert

          ef
        end

        def bundle(*items)
          items.map {|i| EXPLANATORY_TEXT + i.to_pem }.join("\n")
        end

      end
    end
  end
end