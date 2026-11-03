source "https://rubygems.org"

gemspec

# Until sirena releases PlantUML @startsalt support.
gem "sirena", git: "https://github.com/claricle/sirena",
              branch: "main"

# The flavour smoke spec (spec/plantuml_flavor_standoc_spec.rb) converts through a
# real Metanorma flavour; it skips when the gem is absent.
gem "metanorma-standoc"
