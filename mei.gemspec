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

  s.add_dependency "rails", "~> 4.2.5"

  s.add_development_dependency "sqlite3"
end