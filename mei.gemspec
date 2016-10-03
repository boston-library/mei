$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mei/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mei"
  s.version     = Mei::VERSION
  s.authors     = ["Steven Anderson"]
  s.email       = ["sanderson@bpl.org"]
  s.homepage    = "https://github.com/boston-library/mei"
  s.summary     = "A Metadata Enrichment Interface (MEI) for Hydra Forms."
  s.description = "A Metadata Enrichment Interface (MEI) for Hydra Forms."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
  s.add_dependency "simple_form"
  s.add_dependency "active-fedora"
  s.add_dependency "gon"
  s.add_dependency 'curation_concerns', '>= 1.6.1'
  s.add_dependency "qa"
  s.add_dependency 'rest-client', '1.8.0'
  s.add_dependency 'rest-client-components' #Broken in RestClient 2.0: https://github.com/crohr/rest-client-components/issues/13
  s.add_dependency 'rack-cache'

  s.add_development_dependency "sqlite3"
end
