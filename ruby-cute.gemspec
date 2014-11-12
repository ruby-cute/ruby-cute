lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cute/version'

Gem::Specification.new do |s|
  s.name        = "ruby-cute"
  s.version     = Cute::VERSION
  s.authors     = ["Algorille team"]
  s.email       = "ruby-cute-staff@lists.gforge.inria.fr"
  s.homepage    = "http://ruby-cute.gforge.inria.fr/"
  s.summary     = "Critically Useful Tools for Experiments"
  s.description = "Ruby library for controlling experiments"
  s.required_rubygems_version = ">= 1.3.6"
  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "pry", "~> 0.10"

  s.add_dependency 'rest-client', '1.6.7'
  s.add_dependency 'json', '~> 1.8.1'

  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.license = 'CeCILL-B'
end
