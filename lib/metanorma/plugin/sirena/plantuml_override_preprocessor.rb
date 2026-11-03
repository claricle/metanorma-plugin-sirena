# frozen_string_literal: true

require "asciidoctor"
require_relative "plantuml_block_processor"

module Metanorma
  module Plugin
    module Sirena
      # Keeps `[plantuml]` on Sirena when another handler registered the same
      # block name after this gem did.
      #
      # Asciidoctor lets the last registration of a block name win, and a
      # Metanorma flavour registers metanorma-plugin-plantuml lazily, when its
      # converter class loads, which is after this gem was required. A
      # preprocessor runs once every group is active and before parsing, so
      # registering the block again here makes the swap independent of load
      # order and needs no change to the host's documents or Gemfile order.
      class PlantumlOverridePreprocessor <
            ::Asciidoctor::Extensions::Preprocessor
        def process(document, reader)
          registry = document.extensions
          current = registry.find_block_extension("plantuml")
          return reader if current&.instance.is_a?(PlantumlBlockProcessor)

          registry.block(PlantumlBlockProcessor)
          reader
        end
      end
    end
  end
end
