source "https://rubygems.org"

gemspec

# Until sirena releases its PlantUML families. Pinned to a
# revision (not the moving branch) so CI is deterministic; the not-applicable
# table in spec/plantuml_corpus_spec.rb matches this revision. Bump both together.
gem "sirena", git: "https://github.com/claricle/sirena",
              ref: "abe9410491192bad397aa2af6a7a11085bd28817"

# The flavour smoke spec (spec/plantuml_flavor_standoc_spec.rb) converts through a
# real Metanorma flavour; it skips when the gem is absent.
gem "metanorma-standoc"
