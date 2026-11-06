# frozen_string_literal: true

require "digest"
require "fileutils"

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

          svg = ::Sirena.render(source, format: "svg")
          image_path = write_image(parent, svg, attrs)
          create_image_block(parent, image_path, attrs)
        rescue StandardError => e
          warn "sirena: #{e.message}"
          create_pass_block(parent, "sirena: #{e.message}", attrs)
        end

        private

        # Sirena renders SVG only, so the file is always SVG whatever
        # `format` asks for. The target stays inside the images directory,
        # which is resolved against the document directory and created.
        def write_image(parent, svg, attrs)
          target = attrs["target"] || "diagram_#{hex_digest(svg)}.svg"
          outdir = images_dir(parent.document)
          path = ::File.expand_path(target, outdir)
          unless path.start_with?("#{outdir}#{::File::SEPARATOR}")
            raise "target '#{target}' is outside the images directory"
          end

          ::FileUtils.mkdir_p(::File.dirname(path))
          ::File.write(path, svg)
          target
        end

        def images_dir(document)
          base = ::File.expand_path(document.attr("docdir") || ".")
          ::File.expand_path(document.attr("imagesdir") || ".", base)
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
