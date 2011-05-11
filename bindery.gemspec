# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "bindery/version"

Gem::Specification.new do |s|
  s.name        = "bindery"
  s.version     = Bindery::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Glenn Vanderburg"]
  s.email       = ["glv@vanderburg.org"]
  s.homepage    = "http://github.com/glv/bindery"
  s.summary     = %q{Easy ebook generation with Ruby}
  s.description = %q{Bindery is a Ruby library for easy generation of ebooks.
You supply the chapter content (in HTML format) and explain the book's structure to bindery,
and bindery generates the various other files required by ebook formats and assembles them
into a completed book suitable for installation on an ebook reader.}

  s.rubyforge_project = "bindery"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end