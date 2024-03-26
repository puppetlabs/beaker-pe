# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'beaker-pe/version'

Gem::Specification.new do |s|
  s.name        = "beaker-pe"
  s.version     = Beaker::DSL::PE::Version::STRING
  s.authors     = ["Puppetlabs"]
  s.email       = ["qe-team@puppetlabs.com"]
  s.homepage    = "https://github.com/puppetlabs/beaker-pe"
  s.summary     = %q{Beaker PE DSL Helpers!}
  s.description = %q{Puppet Enterprise (PE) Install & Helper library}
  s.license     = 'Apache2'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'fakefs', '~> 2.4', '< 2.6.0'
  s.add_development_dependency 'rake', '~> 13.1.0'
  s.add_development_dependency 'simplecov', '= 0.22.0'
  s.add_development_dependency 'pry', '~> 0.10'

  # Documentation dependencies
  s.add_development_dependency 'yard'
  s.add_development_dependency 'markdown'
  s.add_development_dependency 'activesupport', '~> 7.0'
  s.add_development_dependency 'thin'

  # Run time dependencies
  s.add_runtime_dependency 'beaker', '>= 4.0', '< 6'
  s.add_runtime_dependency 'beaker-puppet', '>=1', '<3'
  s.add_runtime_dependency 'stringify-hash', '~> 0.0.0'
  s.add_runtime_dependency 'beaker-answers', '~> 1.0'
  s.add_runtime_dependency 'beaker-abs'
  s.add_runtime_dependency 'beaker-vmpooler', '~> 1.0'

end

