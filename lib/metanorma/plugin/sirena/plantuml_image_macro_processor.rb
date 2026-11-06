# frozen_string_literal: true

require "asciidoctor"
require_relative "plantuml_rendering"

module Metanorma
  module Plugin
    module Sirena
      # Drop-in for the `plantuml_image::file.puml[]` block macro that
      # metanorma-standoc registers (from metanorma-plugin-plantuml): the file
      # is read relative to the document, includes also resolve beside it, and
      # the image lands where the `[plantuml]` block's does, but the diagram is
      # rendered by Sirena (SVG) instead of the PlantUML JAR (PNG).
      class PlantumlImageMacroProcessor <
            ::Asciidoctor::Extensions::BlockMacroProcessor
        include PlantumlRendering

        use_dsl
        named :plantuml_image

        def process(parent, target, attrs)
          path = resolve(parent, target)
          source = ::File.read(path, encoding: "UTF-8")
          render_block(parent, source, attrs, extra_dirs: [::File.dirname(path)])
        rescue StandardError => e
          abort(parent, target, attrs, e.message)
        end

        private

        def resolve(parent, target)
          base = ::File.dirname(parent.document.attributes["docfile"] || ".")
          parent.document.path_resolver.system_path(target, base)
        end
      end
    end
  end
end
