# frozen_string_literal: true

require "tmpdir"

# Converts AsciiDoc through the plugin's registered extensions.
module ConvertHelper
  def convert_adoc(adoc, attributes = {})
    Asciidoctor.convert(adoc, safe: :safe, standalone: false,
                              attributes: attributes,
                              extension_registry: plantuml_registry)
  end

  def plantuml_registry
    Asciidoctor::Extensions.create do
      block Metanorma::Plugin::Sirena::PlantumlBlockProcessor
      block_macro Metanorma::Plugin::Sirena::PlantumlImageMacroProcessor
    end
  end

  def fixture(name)
    File.read(File.join(__dir__, "..", "fixtures", "plantuml", name))
  end

  def plantuml_block(source, attrs = "plantuml")
    "[#{attrs}]\n....\n#{source}\n....\n"
  end
end
