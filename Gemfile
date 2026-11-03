source "https://rubygems.org"

gemspec

# Until sirena PR #347 (PlantUML activity/usecase/component support) merges.
# Return this to branch: "main" once it has.
gem "sirena", git: "https://github.com/claricle/sirena",
              branch: "feat/plantuml-core-diagrams"

# The flavour smoke spec (spec/plantuml_flavor_standoc_spec.rb) converts through a
# real Metanorma flavour; it skips when the gem is absent.
gem "metanorma-standoc"
