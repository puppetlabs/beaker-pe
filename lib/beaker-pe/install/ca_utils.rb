#Much of this is taken from PuppetSpec:SSL
require "openssl"

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

        # Generate CA bundle with root and intermediate certs, as well as CRL chain and private key for
        # the intermediate CA, pushed to the host for use during PE install with pe_install::signing_ca
        #
        # @param [Host] host  The host to create CA bundle files on.  Defaults to global 'master' object.
        # @param [String] targetdir  Location to save files on host, to be referenced in pe.conf for install.
        # @return [Hash] File names => where they were put on the host
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

        def self_signed_ca(key, name)
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
          CA_EXTENSIONS.each do |ext|
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
          csr.version = 2
          csr.sign(key, DEFAULT_SIGNING_DIGEST)

          csr
        end

        def sign(ca_key, ca_cert, csr, extensions = NODE_EXTENSIONS)
          cert = OpenSSL::X509::Certificate.new

          cert.public_key = csr.public_key
          cert.subject = csr.subject
          cert.issuer = ca_cert.subject
          cert.version = 2
          cert.serial = rand(2**128)

          not_before = just_now
          cert.not_before = not_before
          cert.not_after = not_before + FIVE_YEARS

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