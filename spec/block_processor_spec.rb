require "spec_helper"
require "tmpdir"

RSpec.describe Metanorma::Plugin::Sirena::BlockProcessor do
  it "registers the sirena block" do
    html = Asciidoctor.convert(<<~ADOC, extension_registry: registry)
      [sirena]
      ....
      TBD: diagram source
      ....
    ADOC
    expect(html).to be_a(String)
  end

  context "when rendering a diagram to a file" do
    let(:dir) { Dir.mktmpdir }
    let(:diagram) { "graph TD\n  A-->B" }

    after { FileUtils.remove_entry(dir) }

    def convert(adoc, attrs = {})
      Asciidoctor.convert(adoc, extension_registry: registry, safe: :unsafe,
                                attributes: { "docdir" => dir }.merge(attrs))
    end

    it "names an untargeted image by digest, with an svg extension" do
      html = convert("[sirena,format=png]\n....\n#{diagram}\n....\n")
      expect(html).to match(/src="diagram_\h{12}\.svg"/)
      expect(Dir.glob(File.join(dir, "diagram_*.svg")).size).to eq(1)
    end

    it "creates a missing imagesdir under the document directory" do
      convert("[sirena,target=a.svg]\n....\n#{diagram}\n....\n",
              "imagesdir" => "img")
      expect(File).to exist(File.join(dir, "img", "a.svg"))
    end

    it "refuses a target outside the images directory and keeps compiling" do
      html = nil
      expect do
        html = convert("[sirena,target=../esc.svg]\n....\n#{diagram}\n....\n")
      end.to output(/outside the images directory/).to_stderr
      expect(html).to include("outside the images directory")
      expect(File).not_to exist(File.join(File.dirname(dir), "esc.svg"))
    end
  end

  def registry
    @registry ||= Asciidoctor::Extensions.create do
      block Metanorma::Plugin::Sirena::BlockProcessor
    end
  end
end
