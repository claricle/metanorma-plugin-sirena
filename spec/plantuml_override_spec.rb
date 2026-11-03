# frozen_string_literal: true

require "spec_helper"

# A Metanorma flavour registers metanorma-plugin-plantuml after this gem was
# required; Asciidoctor then lets that later registration win. The swap must
# hold whatever the registration order.
RSpec.describe Metanorma::Plugin::Sirena::PlantumlOverridePreprocessor do
  include ConvertHelper

  let(:dir) { Dir.mktmpdir("plantuml-override") }
  let(:rival) do
    Class.new(Asciidoctor::Extensions::BlockProcessor) do
      use_dsl
      named :plantuml
      on_context :literal
      parse_content_as :raw

      def process(parent, reader, _attrs)
        create_paragraph(parent, "RIVAL:#{reader.source.lines.first}", {})
      end
    end
  end

  def convert_with(*processors)
    registry = Asciidoctor::Extensions.create do
      processors.each { |p| block p }
      preprocessor Metanorma::Plugin::Sirena::PlantumlOverridePreprocessor
    end
    Asciidoctor.convert(plantuml_block(fixture("simple.puml")),
                        safe: :safe, standalone: false,
                        attributes: { "docfile" => File.join(dir, "d.adoc") },
                        extension_registry: registry)
  end

  after { FileUtils.remove_entry(dir) }

  it "renders through Sirena when a rival handler registered later" do
    html = convert_with(Metanorma::Plugin::Sirena::PlantumlBlockProcessor,
                        rival)
    expect(html).to include("_plantuml_images/").and include(".svg")
    expect(html).not_to include("RIVAL:")
  end

  it "leaves a document with only Sirena's handler unchanged" do
    html = convert_with(Metanorma::Plugin::Sirena::PlantumlBlockProcessor)
    expect(html).to include(".svg")
  end
end
