# frozen_string_literal: true

require "asciidoctor"
require_relative "plantuml_rendering"

module Metanorma
  module Plugin
    module Sirena
      # Drop-in for metanorma-plugin-plantuml's `[plantuml]` block: same block
      # name, contexts, format attributes and image emission, but the diagram
      # is rendered by Sirena instead of the PlantUML JAR (see
      # {PlantumlRendering} for the shared behaviour).
      class PlantumlBlockProcessor < ::Asciidoctor::Extensions::BlockProcessor
        include PlantumlRendering

        use_dsl
        named :plantuml
        on_context :literal
        parse_content_as :raw

        def process(parent, reader, attrs)
          render_block(parent, reader.source, attrs)
        end
      end
    end
  end
end
