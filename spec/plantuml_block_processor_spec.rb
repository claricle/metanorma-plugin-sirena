# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metanorma::Plugin::Sirena::PlantumlBlockProcessor do
  include ConvertHelper

  let(:dir) { Dir.mktmpdir("plantuml-spec") }
  let(:docfile) { File.join(dir, "doc.adoc") }
  let(:attributes) { { "docfile" => docfile, "docdir" => dir } }
  let(:images) { File.join(dir, "_plantuml_images") }

  after { FileUtils.remove_entry(dir) }

  def convert(source, block_attrs = "plantuml", extra = {})
    convert_adoc(plantuml_block(source, block_attrs),
                 attributes.merge(extra))
  end

  describe "registration surface" do
    it "is named plantuml on literal blocks with raw content" do
      expect(described_class.config)
        .to include(name: :plantuml, contexts: Set[:literal],
                    content_model: :raw)
    end

    it "is registered by the gem's default extension group" do
      registry = Asciidoctor::Extensions.create
      Asciidoctor::Extensions.groups.each_value do |group|
        registry.instance_exec(&group)
      end
      expect(registry.find_block_extension("plantuml")).not_to be_nil
      expect(registry.find_block_extension("sirena")).not_to be_nil
    end
  end

  describe "relative docfile (as metanorma passes it)" do
    it "renders under the working directory instead of aborting" do
      Dir.chdir(dir) do
        html = convert_adoc(plantuml_block(fixture("simple.puml")),
                            "docfile" => "doc.adoc", "imagesdir" => "images")
        expect(html).to include("<img")
        expect(Dir.glob(File.join(dir, "_plantuml_images", "*.svg")).size)
          .to eq(1)
      end
    end
  end

  describe "rendering" do
    it "writes an SVG under _plantuml_images and emits an image" do
      html = convert(fixture("simple.puml"))
      files = Dir.glob(File.join(images, "plantuml_*.svg"))
      expect(files.size).to eq(1)
      expect(File.read(files.first)).to include("<svg")
      expect(html).to include("<img", "_plantuml_images/plantuml_")
    end

    it "names the file after the @startsalt argument" do
      convert(fixture("named.puml"))
      expect(File.exist?(File.join(images, "my_diagram.svg"))).to be true
    end

    it "uses plantuml-image-format when no format is given" do
      convert(fixture("simple.puml"), "plantuml", "plantuml-image-format" => "svg")
      expect(Dir.glob(File.join(images, "*.svg")).size).to eq(1)
    end

    it "accepts format=svg and formats=svg" do
      convert(fixture("named.puml"), "plantuml,format=svg")
      expect(File.exist?(File.join(images, "my_diagram.svg"))).to be true
    end

    it "passes id, title, width, alt through to the image" do
      html = convert(fixture("simple.puml"),
                     'plantuml,id=fig1,width=300,alt="A figure"')
      expect(html).to include('id="fig1"', "A figure", 'width="300"')
    end

    it "renders @startuml sequence diagrams through Sirena's PlantUML notation" do
      html = convert("@startuml\nAlice -> Bob: hi\nBob --> Alice: ok\n@enduml",
                     "plantuml")
      expect(html).to include("<img")
      expect(Dir[File.join(images, "*.svg")].first)
        .to satisfy { |f| File.read(f).include?("Alice") }
    end

    it "makes the target relative to imagesdir" do
      doc = Asciidoctor.load(plantuml_block(fixture("named.puml")),
                             safe: :safe,
                             attributes: attributes.merge("imagesdir" => "out"),
                             extension_registry: plantuml_registry)
      expect(doc.blocks.first.attr("target"))
        .to eq("../_plantuml_images/my_diagram.svg")
    end
  end

  describe "graceful abort" do
    it "falls back to a plantuml listing when processing is disabled" do
      html = nil
      expect do
        html = convert(fixture("simple.puml"), "plantuml",
                       "plantuml-disabled" => "")
      end.to output(/PlantUML processing disabled/).to_stderr
      expect(html).to include("@startsalt")
      expect(html).not_to include("<img")
    end

    it "falls back for a source with no @start directive" do
      html = nil
      expect { html = convert("A -> B") }
        .to output(/must start with @start/).to_stderr
      expect(html).to include("A -&gt; B")
    end

    it "falls back for a missing @end directive" do
      expect { convert("@startsalt\n{\n}\n") }
        .to output(/without matching @endsalt/).to_stderr
    end

    it "falls back, naming the limit, for formats Sirena cannot produce" do
      html = nil
      expect { html = convert(fixture("simple.puml"), "plantuml,format=png") }
        .to output(/SVG only/).to_stderr
      expect(html).to include("@startsalt")
      expect(Dir.glob(File.join(images, "*"))).to be_empty
    end
  end
end
