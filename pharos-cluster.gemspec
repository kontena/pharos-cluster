
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pharos/version"

Gem::Specification.new do |spec|
  spec.name          = "pharos-cluster"
  spec.version       = Pharos::VERSION.sub('-', '.')
  spec.authors       = ["Kontena, Inc."]
  spec.email         = ["info@kontena.io"]

  spec.summary       = "Kontena Pharos cluster manager"
  spec.description   = "Kontena Pharos cluster manager"
  spec.homepage      = "https://github.com/kontena/pharos-cluster"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '~> 2.4'

  spec.add_runtime_dependency "clamp", "1.2.1"
  spec.add_runtime_dependency "pastel"
  spec.add_runtime_dependency "kubeclient"
  spec.add_runtime_dependency "net-ssh", "5.0.0.beta2"
  spec.add_runtime_dependency "ed25519", "1.2.4"
  spec.add_runtime_dependency "bcrypt_pbkdf", ">= 1.0", "< 2.0"
  spec.add_runtime_dependency "dry-struct"
  spec.add_runtime_dependency "dry-validation"
  spec.add_runtime_dependency "deep_merge"
  spec.add_runtime_dependency "fugit"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "fakefs", "~> 0.13"
  spec.add_development_dependency "rubocop", "~> 0.53"
end
