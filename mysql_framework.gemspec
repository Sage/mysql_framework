# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mysql_framework/version'

Gem::Specification.new do |spec|
  spec.name          = 'mysql_framework'
  spec.version       = MysqlFramework::VERSION
  spec.authors       = ['Sage']
  spec.email         = ['support@sageone.com']

  spec.summary       = 'A lightweight framework to provide managers for working with MySQL.'
  spec.description   = 'A lightweight framework to provide managers for working with MySQL.'
  spec.homepage      = 'https://github.com/sage/mysql_framework'
  spec.license       = 'MIT'

  spec.files         = Dir.glob("{bin,lib,spec}/**/**/**")
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'

  spec.add_dependency 'mysql2', '~> 0.4.10'
  spec.add_dependency 'redlock'
end
