lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cute/version'

Gem::Specification.new do |s|
  s.name        = "ruby-cute"
  s.version     = Cute::VERSION
  s.authors     = ["Algorille/Madynes/RESIST teams at Inria/LORIA"]
  s.email       = "lucas.nussbaum@inria.fr"
  s.homepage    = "http://ruby-cute.github.io/"
  s.summary     = "Critically Useful Tools for Experiments"
  s.description = "Ruby library for controlling experiments"
  s.required_rubygems_version = ">= 1.3.6"
  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "rspec", "~> 3.1"
  s.add_development_dependency "pry", "~> 0.10"
  s.add_development_dependency "webmock", "~> 1.20"
  s.add_development_dependency "yard", "~> 0.8"
  s.add_development_dependency "simplecov", "~> 0.7"

  s.add_dependency 'rest-client', '>= 1.6'
  s.add_dependency 'json', '>= 1.8'
  s.add_dependency 'ipaddress', '>= 0.8'
  s.add_dependency 'net-ssh', '>= 3.2'
  s.add_dependency 'net-ssh-multi', '>= 1.2'
  s.add_dependency 'net-scp', '>= 1.2'

  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.license = 'CeCILL-B'
end
