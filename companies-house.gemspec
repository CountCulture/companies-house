# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "companies_house/version"

Gem::Specification.new do |s|
  s.name        = "companies-house"
  s.version     = CompaniesHouse::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Rob McKinnon", "Chris Taggart"]
  s.email       = ["rob ~@nospam@~ rubyforge.org"]
  s.homepage    = "https://github.com/robmckinnon/companies-house"
  s.summary     = "Ruby library for using UK CompaniesHouse API"
  s.description = "Ruby API to UK Companies House XML Gateway."

  s.rubyforge_project = "companies-house"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency 'morph'
  s.add_dependency 'nokogiri'
  s.add_dependency 'haml'
  s.add_dependency 'yaml'
  
end
