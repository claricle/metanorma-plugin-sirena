# frozen_string_literal: true

require "spec_helper"

begin
  require "metanorma-standoc"
rescue LoadError
  nil
end

# The swap for real: the Metanorma standoc flavour loads
# metanorma-plugin-plantuml and registers its `[plantuml]` handler itself,
# after this gem. With no edit to the document, the block still renders
# through Sirena (no PlantUML processing-instruction in the output, and no
# Java involved).
RSpec.describe "Metanorma flavour with metanorma-plugin-sirena loaded",
               skip: (defined?(Metanorma::Standoc::Converter) ? false : "metanorma-standoc not installed") do
  let(:dir) { Dir.mktmpdir("plantuml-flavor") }
  let(:adoc) do
    <<~ADOC
      = Doc
      :nodoc:
      :no-isobib:
      :docfile: #{dir}/doc.adoc
      :imagesdir: images

      == Clause

      [plantuml]
      ....
      @startsalt
      {
        hi
      }
      @endsalt
      ....
    ADOC
  end

  after { FileUtils.remove_entry(dir) }

  it "renders an unchanged [plantuml] block through Sirena" do
    xml = Asciidoctor.convert(adoc, backend: :standoc, safe: :safe,
                                    standalone: true)
    svg = Dir[File.join(dir, "_plantuml_images", "*.svg")]
    expect(svg.size).to eq(1)
    expect(File.read(svg.first)).to include('baseProfile="tiny"')
                                .and include(">hi</text>")
    expect(xml).to include("_plantuml_images/")
    expect(xml).not_to include("<?plantuml")
  end
end
