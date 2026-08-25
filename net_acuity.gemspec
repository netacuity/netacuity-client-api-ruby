Gem::Specification.new do |spec|
  spec.name        = 'net_acuity'
  spec.version     = '7.0.0'
  spec.summary     = 'Ruby client API for the NetAcuity Server'
  spec.description = 'Query a NetAcuity server for IP intelligence data using the XML UDP protocol.'
  spec.authors     = ['Digital Envoy']
  spec.homepage    = 'https://github.com/netacuity/netacuity-client-api-ruby'
  spec.license     = 'Apache-2.0'

  spec.metadata['source_code_uri'] = 'https://github.com/netacuity/netacuity-client-api-ruby'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/netacuity/netacuity-client-api-ruby/issues'

  spec.files       = Dir['lib/**/*.rb', 'examples/**/*.rb', 'README.md', 'LICENSE', 'NOTICE', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0'

  spec.add_dependency 'nokogiri'

  spec.add_development_dependency 'rspec', '~> 3.0'
end