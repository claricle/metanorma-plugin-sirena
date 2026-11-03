# frozen_string_literal: true

module Metanorma
  module Plugin
    module Sirena
      # Renders diagram blocks through Sirena, the pure-Ruby diagram
      # interpreter. Drop-in for the `[plantuml]` block of
      # metanorma-plugin-plantuml: same block name, same format options,
      # no Java and no external renderer.
      class BlockProcessor < ::Asciidoctor::Extensions::BlockProcessor
        use_dsl
        named :sirena
        on_context :literal
        parse_content_as :raw

        def process(parent, reader, attrs)
          source = reader.source
          format = (attrs["format"] || "svg").to_s.downcase

          svg = ::Sirena.render(source, format: format)
          image_path = write_image(parent, svg, attrs, format)
          block = create_image_block(parent, image_path, attrs)
          block
        rescue ::Sirena::Error => e
          warn "sirena: #{e.message}"
          create_pass_block(parent, "sirena: #{e.message}", attrs)
        end

        private

        def write_image(parent, svg, attrs, format)
          target = attrs["target"] || "diagram_#{hexdigest(svg)}.#{format}"
          outdir = parent.document.attr("imagesdir") || "."
          path = ::File.join(outdir, target)
          ::File.write(path, svg)
          target
        end

        def hex_digest(str)
          ::Digest::SHA256.hexdigest(str)[0, 12]
        end

        def create_image_block(parent, path, attrs)
          attrs["target"] = path
          ::Asciidoctor::Block.new(parent, :image, content_model: :empty,
                                                   attributes: attrs)
        end

        def create_pass_block(parent, content, attrs)
          ::Asciidoctor::Block.new(parent, :pass, content_model: :raw,
                                                  source: content)
        end
      end
    end
  end
end
