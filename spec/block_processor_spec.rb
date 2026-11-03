require "spec_helper"

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

  def registry
    @registry ||= Asciidoctor::Extensions.create do
      block Metanorma::Plugin::Sirena::BlockProcessor
    end
  end
end
