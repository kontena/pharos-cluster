
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "kuntena/version"

Gem::Specification.new do |spec|
  spec.name          = "kuntena"
  spec.version       = Kuntena::VERSION
  spec.authors       = ["Jari Kolehmainen"]
  spec.email         = ["jari.kolehmainen@gmail.com"]

  spec.summary       = "Kontena-ish Kubernetes CLI"
  spec.description   = "Kontena-ish Kubernetes CLI"
  spec.homepage      = "https://github.com/jakolehm/kuntena"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "clamp", "1.2.1"
  spec.add_runtime_dependency "kubeclient"
  spec.add_runtime_dependency "tty-table"
  spec.add_runtime_dependency "tty-spinner"
  spec.add_runtime_dependency "net-ssh"
  spec.add_runtime_dependency "net-scp"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
