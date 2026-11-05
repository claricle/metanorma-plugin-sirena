# frozen_string_literal: true

require "spec_helper"
require "rexml/document"

# Ports metanorma-plugin-plantuml's fixture corpus
# (spec/fixtures/corpus/*.puml, copied verbatim; the includes/ directory holds
# the files some fixtures `!include`).
#
# Every fixture is in exactly one of two tables. RENDERED fixtures must give
# an image holding valid SVG (and, where listed, the key text). NOT_APPLICABLE
# fixtures need something Sirena does not set out to provide, stated per
# fixture; the drop-in contract for them is a warning and the upstream-style
# source listing, never an exception.
RSpec.describe Metanorma::Plugin::Sirena::PlantumlBlockProcessor,
               "upstream fixture corpus" do
  include ConvertHelper

  corpus_dir = File.expand_path("fixtures/corpus", __dir__)

  # fixture => text the SVG must contain (nil: only valid SVG is asserted).
  rendered = {
    "components" => "Web App",
    "plantuml-lrg-1-12-simple" => nil, "plantuml-lrg-1-12" => nil,
    "plantuml-lrg-1-15" => nil, "plantuml-lrg-1-19" => nil,
    "plantuml-lrg-14-1" => nil, "plantuml-lrg-14-8-2" => nil,
    "plantuml-lrg-19-0-1" => nil, "plantuml-lrg-2-8" => nil,
    "plantuml-lrg-2-9" => nil, "plantuml-lrg-3-27" => nil,
    "plantuml-lrg-3-5" => nil, "plantuml-lrg-3-6" => nil,
    "plantuml-lrg-5-12" => nil, "plantuml-lrg-5-4" => nil,
    "plantuml-lrg-6-10-4" => nil, "plantuml-lrg-6-15" => nil,
    "plantuml-lrg-6-19" => nil, "plantuml-lrg-6-3" => nil,
    "plantuml-lrg-6-4" => nil, "plantuml-lrg-7-18-4" => nil,
    "plantuml-lrg-7-4-3" => nil, "plantuml-lrg-7-5" => nil,
    "plantuml-lrg-8-4-4" => nil, "plantuml-lrg-8-9-1" => nil,
    "plantuml-lrg-9-15" => nil, "plantuml-lrg-layout-option" => nil,
    # `!include` / `!includesub` / `!startsub`, expanded by the plugin.
    "plantuml-lrg-25-10-1" => "Response 2",
    "plantuml-lrg-25-10-1-include" => "Response 2",
    "plantuml-lrg-25-10-1-include-a" => "Response 2",
    "plantuml-lrg-25-10-2" => "API Gateway",
    "plantuml-lrg-25-11" => "stuff2",
    "subpart" => "stuff4",
    # Activity `kill`.
    "plantuml-lrg-6-5" => "condition?",
    # Class and state diagrams, rendered by Sirena's PlantUML class and
    # state families (sirena#353).
    "plantuml-lrg-3-8" => "+getName()",
    "plantuml-lrg-3-10" => "On last defined class",
    "plantuml-lrg-3-11-3" => "+void start(int timeoutms)",
    "plantuml-lrg-3-13" => "ArrayList",
    "plantuml-lrg-3-35-4" => "[blue,plain,16]",
    "plantuml-lrg-9-3-1" => "NewValuePreview",
    "plantuml-lrg-9-5" => "Accumulate Enough Data",
    # Families Sirena renders since the pinned revision (see Gemfile).
    "plantuml-lrg-15-2" => "VPN Server",
    "plantuml-lrg-6-25-2" => "test of color",
    "plantuml-custom-filename" => "My_Number",
    "plantuml-lrg-13-1-2" => "210.x.x.x/24",
    "plantuml-lrg-13-4-1" => "192.168.10.0/24",
    "plantuml-lrg-10-1-2" => "Clock_0",
    "plantuml-lrg-10-16" => "Web Browser",
    "plantuml-lrg-10-7-2" => "Season",
    "plantuml-lrg-20-3" => "card_id : number"
  }.freeze

  object = "object diagram (object/map), not a Sirena PlantUML family"
  other = "PlantUML language Sirena does not implement"
  not_applicable = {
    "plantuml-lrg-1-12-invalid" => "deliberately missing @enduml: the " \
                                   "contract is the abort-to-listing",
    "sequences" => "include library holding two diagrams, not one " \
                   "diagram; rendered through its includers",
    "plantuml-lrg-27-3" => "!include <awslib/...> needs PlantUML's " \
                           "bundled standard library",
    "plantuml-lrg-5-7" => "<img:file> embeds an external raster image",
    "plantuml-lrg-11-1" => "#{other} (json)",
    "plantuml-lrg-11-2" => "#{other} (json)",
    "plantuml-lrg-11-3" => "#{other} (json)",
    "plantuml-lrg-2-18" => "json element mixed into a use case diagram",
    "plantuml-lrg-12-3-1" => "#{other} (yaml)",
    "plantuml-lrg-12-3-2" => "#{other} (yaml)",
    "plantuml-lrg-12-6" => "#{other} (yaml)",
    "plantuml-lrg-16-1-1" => "#{other} (gantt)",
    "plantuml-lrg-17-2" => "#{other} (mindmap)",
    "plantuml-lrg-17-3" => "#{other} (mindmap)",
    "plantuml-lrg-17-4" => "#{other} (mindmap)",
    "plantuml-lrg-17-6-3" => "#{other} (mindmap)",
    "plantuml-lrg-18-1" => "#{other} (wbs)",
    "plantuml-lrg-18-7" => "#{other} (wbs)",
    "plantuml-lrg-4-2" => object, "plantuml-lrg-4-6-3" => object,
    "plantuml-lrg-4-6-5" => object, "plantuml-lrg-4-7" => object,
    "plantuml-lrg-4-8" => object,
  }.freeze

  let(:dir) { Dir.mktmpdir("plantuml-corpus") }
  let(:attrs) { { "docfile" => File.join(dir, "doc.adoc") } }
  let(:block) do
    includes = "#{corpus_dir};#{File.join(corpus_dir, 'includes')}"
    lambda do |source|
      plantuml_block(source, "plantuml,includedirs=\"#{includes}\"")
    end
  end

  after { FileUtils.remove_entry(dir) }

  it "puts every fixture in exactly one table" do
    names = Dir[File.join(corpus_dir, "*.puml")].map do |path|
      File.basename(path, ".puml")
    end

    expect(rendered.keys + not_applicable.keys).to match_array(names)
  end

  rendered.each do |name, text|
    it "renders #{name} through Sirena" do
      html = convert_adoc(block.call(File.read(File.join(corpus_dir, "#{name}.puml"))), attrs)
      svg_path = File.join(dir, html[/src="([^"]+\.svg)"/, 1])
      svg = File.read(svg_path)

      expect(REXML::Document.new(svg).root.name).to eq("svg")
      expect(svg).to include(text) if text
    end
  end

  not_applicable.each do |name, reason|
    it "lists #{name} (#{reason})" do
      html = nil
      expect do
        html = convert_adoc(block.call(File.read(File.join(corpus_dir, "#{name}.puml"))), attrs)
      end.to output(/\S/).to_stderr
      expect(html).to include("<pre")
    end
  end
end
