source ENV['GEM_SOURCE'] || "https://rubygems.org"

gemspec

def location_for(place, fake_version = nil)
  if place =~ /^(git:[^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

group :acceptance_testing do
  gem "beaker", *location_for(ENV['BEAKER_VERSION'] || '~> 4.0')
  gem "beaker-vmpooler", *location_for(ENV['BEAKER_VMPOOLER_VERSION'] || '~> 1.3')
  gem "beaker-abs", *location_for(ENV['BEAKER_ABS_VERSION'] || '~> 0.8')
end

gem "scooter", *location_for(ENV['SCOOTER_VERSION'] || '~> 4.3')

gem 'deep_merge'

if File.exist? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end
