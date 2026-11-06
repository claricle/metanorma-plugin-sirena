source "https://rubygems.org"

gemspec

# Until sirena releases its PlantUML families. Pinned to a
# revision (not the moving branch) so CI is deterministic; the not-applicable
# table in spec/plantuml_corpus_spec.rb matches this revision. Bump both together.
gem "sirena", git: "https://github.com/claricle/sirena",
              ref: "c58d5a656d42bb6a409654fe68f8036a58a6f773"

# The flavour smoke spec (spec/plantuml_flavor_standoc_spec.rb) converts through a
# real Metanorma flavour; it skips when the gem is absent.
gem "metanorma-standoc"
