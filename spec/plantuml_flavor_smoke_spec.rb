# frozen_string_literal: true

require "spec_helper"

# Plugin swap: a document written for metanorma-plugin-plantuml (the
# bpg-tagged-pdf-syntax SE_Caption section, verbatim) converts with this
# plugin's `[plantuml]` handler and no edit to the document.
RSpec.describe "drop-in swap for metanorma-plugin-plantuml" do
  include ConvertHelper

  let(:dir) { Dir.mktmpdir("plantuml-smoke") }
  let(:source) do
    File.read(File.join(__dir__, "fixtures", "bpg_se_caption.adoc"))
  end

  after { FileUtils.remove_entry(dir) }

  it "renders every [plantuml] block of an existing document to an svg" do
    html = convert_adoc(source, "docfile" => File.join(dir, "doc.adoc"),
                                "imagesdir" => "images",
                                "plantuml-image-format" => "svg")
    blocks = source.scan(/^\[plantuml\]$/).size
    expect(blocks).to be >= 2
    expect(html.scan(%r{<img src="[^"]*_plantuml_images/[^"]+\.svg"}).size)
      .to eq(blocks)
    expect(Dir[File.join(dir, "_plantuml_images", "*.svg")].size)
      .to eq(blocks)
  end
end
