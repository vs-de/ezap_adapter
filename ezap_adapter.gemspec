# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ezap_adapter/version'

Gem::Specification.new do |gem|
  gem.name          = "ezap_adapter"
  gem.version       = EzapAdapter::VERSION
  gem.authors       = ["Valentin Schulte"]
  gem.email         = ["valentin.schulte@wecuddle.de"]
  gem.description   = %q{Gem to connect a ruby app to an ezap-service via ServiceAdapter and RemoteModel classes}
  gem.summary       = %q{Gem to connect a ruby app to an ezap-service}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
