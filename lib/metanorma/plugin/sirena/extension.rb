# frozen_string_literal: true

require "asciidoctor"
require "digest"
require_relative "block_processor"
require_relative "plantuml_block_processor"

module Metanorma
  module Plugin
    module Sirena
      class Extensions
        # AsciiDoc extension registration: the `sirena` block and the
        # drop-in `[plantuml]` block.
        ::Asciidoctor::Extensions.register do
          block ::Metanorma::Plugin::Sirena::BlockProcessor
          block ::Metanorma::Plugin::Sirena::PlantumlBlockProcessor
        end
      end
    end
  end
end
