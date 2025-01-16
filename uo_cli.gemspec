require_relative 'lib/uo_cli/version'

Gem::Specification.new do |spec|
  spec.name            = 'urbanopt-cli'
  spec.version         = URBANopt::CLI::VERSION
  spec.authors         = ['NREL URBANopt team']
  spec.email           = ['nathan.moore@nrel.gov']
  spec.license         = 'Nonstandard'

  spec.summary         = 'Command Line Interface for URBANopt district building simulations'
  spec.description     = 'Interfacing with URBANopt'
  spec.homepage        = 'https://docs.urbanopt.net/'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/urbanopt/urbanopt-cli'
    spec.metadata['documentation_uri'] = 'https://docs.urbanopt.net/'
    spec.metadata['bug_tracker_uri'] = 'https://github.com/urbanopt/urbanopt-cli/issues'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.files += Dir.glob('example_files/**')
  spec.bindir = 'bin'
  spec.executables = ['uo']
  spec.require_paths = ['lib', 'example_files']
  spec.required_ruby_version = '3.2.2'

  # use specific versions of urbanopt and openstudio dependencies while under heavy development
  spec.add_runtime_dependency 'optimist', '~> 3.2'
  # spec.add_runtime_dependency 'urbanopt-geojson', '~> 0.11.2'
  # spec.add_runtime_dependency 'urbanopt-reopt', '~> 0.12.0'
  # spec.add_runtime_dependency 'urbanopt-reporting', '~> 0.10.1'
  # spec.add_runtime_dependency 'urbanopt-rnm-us', '~> 0.7.0'
  # spec.add_runtime_dependency 'urbanopt-scenario', '~> 0.12.0'

  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'simplecov', '0.22.0'
  spec.add_development_dependency 'simplecov-lcov', '0.8.0'
end
