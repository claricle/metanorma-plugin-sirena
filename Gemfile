source "https://rubygems.org"

gemspec

# Until sirena releases PlantUML activity/usecase/component support. Pinned to a
# revision (not the moving branch) so CI is deterministic; the not-applicable
# table in spec/plantuml_corpus_spec.rb matches this revision. Bump both together.
gem "sirena", git: "https://github.com/claricle/sirena",
              ref: "fde0b6f3eb57e32a9ee401d9154af46393ef27da"

# The flavour smoke spec (spec/plantuml_flavor_standoc_spec.rb) converts through a
# real Metanorma flavour; it skips when the gem is absent.
gem "metanorma-standoc"
