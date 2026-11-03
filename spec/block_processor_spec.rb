require "spec_helper"

RSpec.describe Metanorma::Plugin::Sirena::BlockProcessor do
  it "registers the sirena block" do
    doc = Asciidoctor.convert(<<~ADOC, extension_registry: registry)
      [sirena]
      ....
      TBD: diagram source
      ....
    ADOC
  end

  def registry
    @registry ||= Asciidoctor::Extensions.create do
      block_processor :sirena, Metanorma::Plugin::Sirena::BlockProcessor
    end
  end
end
