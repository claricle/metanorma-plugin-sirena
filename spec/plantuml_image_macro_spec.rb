# frozen_string_literal: true

require "spec_helper"

# `plantuml_image::file.puml[]` is registered by metanorma-standoc for the
# PlantUML JAR (PNG). With this gem loaded it renders through Sirena (SVG).
RSpec.describe Metanorma::Plugin::Sirena::PlantumlImageMacroProcessor do
  include ConvertHelper

  let(:dir) { Dir.mktmpdir("plantuml-macro") }
  let(:attributes) { { "docfile" => File.join(dir, "doc.adoc") } }
  let(:images) { File.join(dir, "_plantuml_images") }

  before do
    File.write(File.join(dir, "m.puml"), fixture("named.puml"))
    File.write(File.join(dir, "bad.puml"), "not a diagram")
  end

  after { FileUtils.remove_entry(dir) }

  def convert(line, attrs = attributes, registry = plantuml_registry)
    Asciidoctor.convert(line, safe: :safe, standalone: false,
                              attributes: attrs, extension_registry: registry)
  end

  it "is the plantuml_image block macro" do
    expect(described_class.config).to include(name: :plantuml_image)
  end

  it "renders the file to an SVG named after the diagram, no PNG" do
    html = convert("plantuml_image::m.puml[id=fig1,width=300,alt=Pic]")
    expect(Dir[File.join(images, "*")].map { |f| File.basename(f) })
      .to eq(["my_diagram.svg"])
    expect(File.read(File.join(images, "my_diagram.svg"))).to include("<svg")
    expect(html).to include("<img", "_plantuml_images/my_diagram.svg",
                            'id="fig1"', 'width="300"', "Pic")
  end

  it "resolves !include beside the diagram file" do
    FileUtils.mkdir_p(File.join(dir, "sub"))
    File.write(File.join(dir, "sub", "inc.puml"), "Alice -> Bob: from-include")
    File.write(File.join(dir, "sub", "m2.puml"),
               "@startuml\n!include inc.puml\n@enduml")
    convert("plantuml_image::sub/m2.puml[]")
    svg = Dir[File.join(images, "*.svg")]
    expect(File.read(svg.first)).to include("from-include")
  end

  it "warns and falls back to a listing on a bad diagram" do
    html = nil
    expect { html = convert("plantuml_image::bad.puml[]") }
      .to output(/@start/).to_stderr
    expect(html).to include("listingblock", "not a diagram")
    expect(html).not_to include("<img")
  end

  it "warns and falls back to a listing on a missing file" do
    html = nil
    expect { html = convert("plantuml_image::nope.puml[]") }
      .to output(/nope\.puml/).to_stderr
    expect(html).to include("listingblock", "nope.puml")
  end

  it "falls back when processing is disabled" do
    html = nil
    expect do
      html = convert("plantuml_image::m.puml[]",
                     attributes.merge("plantuml-disabled" => ""))
    end.to output(/disabled/).to_stderr
    expect(html).not_to include("<img")
  end

  it "reports a format Sirena cannot render" do
    html = nil
    expect { html = convert("plantuml_image::m.puml[format=png]") }
      .to output(/SVG only/).to_stderr
    expect(html).not_to include("<img")
  end

  it "is registered by the gem's default extension group" do
    registry = Asciidoctor::Extensions.create
    Asciidoctor::Extensions.groups.each_value { |g| registry.instance_exec(&g) }
    expect(registry.find_block_macro_extension("plantuml_image")).not_to be_nil
  end

  context "when a rival registered the same macro later" do
    let(:rival) do
      Class.new(Asciidoctor::Extensions::BlockMacroProcessor) do
        use_dsl
        named :plantuml_image
        def process(parent, target, _attrs)
          create_paragraph(parent, "RIVAL:#{target}", {})
        end
      end
    end

    it "still renders through Sirena" do
      later = rival
      registry = Asciidoctor::Extensions.create do
        block_macro Metanorma::Plugin::Sirena::PlantumlImageMacroProcessor
        block_macro later
        preprocessor Metanorma::Plugin::Sirena::PlantumlOverridePreprocessor
      end
      html = convert("plantuml_image::m.puml[]", attributes, registry)
      expect(html).to include("_plantuml_images/my_diagram.svg")
      expect(html).not_to include("RIVAL:")
    end
  end
end
