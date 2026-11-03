# frozen_string_literal: true

require "asciidoctor"
require "digest"
require_relative "block_processor"

module Metanorma
  module Plugin
    module Sirena
      class Extensions
        # AsciiDoc extension registration: `sirena` block processor now;
        # a drop-in `[plantuml]` handler follows once Sirena's PlantUML
        # language support lands (see claricle/sirena).
        ::Asciidoctor::Extensions.register do
          block_processor :sirena,
                          ::Metanorma::Plugin::Sirena::BlockProcessor
        end
      end
    end
  end
end
