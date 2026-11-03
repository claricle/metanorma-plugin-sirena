# frozen_string_literal: true

require "spec_helper"

# Ports metanorma-plugin-plantuml's fixture corpus
# (spec/fixtures/plantuml/*.puml, copied verbatim). The upstream spec asserts
# that PlantUML renders every file; Sirena implements a subset of PlantUML,
# so the port asserts the drop-in contract instead: every file is handled
# without raising, and gives an image when Sirena supports it or the
# upstream-style source listing when it does not.
RSpec.describe Metanorma::Plugin::Sirena::PlantumlBlockProcessor,
               "upstream fixture corpus" do
  include ConvertHelper

  corpus_dir = File.expand_path("fixtures/corpus", __dir__)
  rendered = %w[
    components plantuml-lrg-1-12-simple plantuml-lrg-1-12 plantuml-lrg-1-15 plantuml-lrg-1-19
    plantuml-lrg-14-1 plantuml-lrg-14-8-2 plantuml-lrg-19-0-1 plantuml-lrg-2-8 plantuml-lrg-2-9
    plantuml-lrg-3-27 plantuml-lrg-3-5 plantuml-lrg-3-6 plantuml-lrg-5-12 plantuml-lrg-5-4
    plantuml-lrg-6-10-4 plantuml-lrg-6-15 plantuml-lrg-6-19 plantuml-lrg-6-3 plantuml-lrg-6-4
    plantuml-lrg-7-18-4 plantuml-lrg-7-4-3 plantuml-lrg-7-5 plantuml-lrg-8-4-4 plantuml-lrg-8-9-1
    plantuml-lrg-9-15 plantuml-lrg-layout-option
  ]

  let(:dir) { Dir.mktmpdir("plantuml-corpus") }

  after { FileUtils.remove_entry(dir) }

  Dir[File.join(corpus_dir, "*.puml")].each do |path|
    name = File.basename(path, ".puml")

    it "handles #{name}" do
      html = nil
      expect do
        html = convert_adoc(plantuml_block(File.read(path)),
                            "docfile" => File.join(dir, "doc.adoc"))
      end.to output(rendered.include?(name) ? "" : /\S/).to_stderr
      expect(html).to include(rendered.include?(name) ? "<img" : "<pre")
    end
  end
end
