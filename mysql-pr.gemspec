# frozen_string_literal: true

require_relative "lib/mysql-pr/version"

Gem::Specification.new do |spec|
  spec.name = "mysql-pr"
  spec.version = MysqlPR::VERSION
  spec.authors = ["Tomita Masahiro", "Alex Jokela"]
  spec.email = ["tommy@tmtm.org", "alex@camulus.com"]

  spec.summary = "Pure Ruby MySQL connector"
  spec.description = "A pure Ruby MySQL client library. No native extensions required."
  spec.homepage = "https://github.com/ajokela/mysql-pr"
  spec.license = "Ruby"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
