# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'burrow/version'

Gem::Specification.new do |spec|
  spec.name          = "burrow"
  spec.version       = Burrow::VERSION
  spec.authors       = ["Krzysztof Zych"]
  spec.email         = ["krzysztof.zych@efigence.com"]
  spec.description   = %q{Instead of writing code to estabilish your queues and exchanges, declare them in a simple format and build it with a single method.}
  spec.summary       = %q{Declaratively express your AMQP topology when connecting.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
  spec.add_runtime_dependency "bunny", "~> 1.5"
end
