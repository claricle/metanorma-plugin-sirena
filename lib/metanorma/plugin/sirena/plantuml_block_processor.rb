# frozen_string_literal: true

require "fileutils"
require "pathname"
require "sirena"
require "sirena/notation/plantuml"
require_relative "plantuml_preprocessor"

module Metanorma
  module Plugin
    module Sirena
      # Drop-in for metanorma-plugin-plantuml's `[plantuml]` block: same block
      # name, contexts, format attributes and image emission, but the diagram
      # is rendered by Sirena instead of the PlantUML JAR.
      #
      # Sirena renders SVG only, so `png`, `pdf`, `txt` and `eps` requests are
      # reported and the block falls back to a PlantUML listing, exactly like
      # any other render failure.
      class PlantumlBlockProcessor < ::Asciidoctor::Extensions::BlockProcessor
        use_dsl
        named :plantuml
        on_context :literal
        parse_content_as :raw

        KNOWN_FORMATS = %w[png svg pdf txt eps].freeze
        RENDERABLE_FORMATS = %w[svg].freeze
        DEFAULT_FORMAT = "svg"
        IMAGE_ATTRS = %w[id align float title role width height alt].freeze
        IMAGES_SUBDIR = "_plantuml_images"

        def process(parent, reader, attrs)
          source = reader.source
          if parent.document.attr("plantuml-disabled")
            return abort(parent, source, attrs, "PlantUML processing disabled")
          end

          formats = parse_formats(attrs, parent.document)
          image_block(parent, attrs, formats.map do |format|
            generate_file(parent, source, format, attrs)
          end, formats)
        rescue StandardError => e
          abort(parent, source, attrs, e.message)
        end

        private

        def abort(parent, text, attrs, message)
          warn message
          listing_attrs = attrs.reject { |k, _| k.to_s.match?(/^\d+$/) }
          listing_attrs["language"] = "plantuml"
          create_listing_block(parent, text, listing_attrs)
        end

        def parse_formats(attrs, document)
          requested = if attrs["formats"]
                        attrs["formats"].split(",").map { |f| normalise(f) }
                      elsif attrs["format"]
                        [normalise(attrs["format"])]
                      else
                        [normalise(document.attr("plantuml-image-format") ||
                                   DEFAULT_FORMAT)]
                      end
          known = requested.select { |f| KNOWN_FORMATS.include?(f) }
          known.empty? ? [DEFAULT_FORMAT] : known
        end

        def normalise(format)
          format.to_s.strip.downcase
        end

        def generate_file(parent, source, format, attrs)
          raise "Sirena renders SVG only; format '#{format}' is unsupported" unless RENDERABLE_FORMATS.include?(format)

          validate_source(source)
          svg = ::Sirena.render(preprocess(source, parent.document, attrs))
          localdir, relative = output_dirs(parent.document)
          filename = "#{base_name(source)}.#{format}"
          ::File.write(::File.join(localdir, IMAGES_SUBDIR, filename), svg)
          ::File.join(relative, filename)
        end

        def preprocess(source, document, attrs)
          dirs = [localdir(document), *include_dirs(document, attrs)]
          PlantumlPreprocessor.new(dirs).expand(source)
        end

        # `includedirs` (block) and `plantuml-includedirs` (document) are
        # semicolon-separated and relative to the document directory.
        def include_dirs(document, attrs)
          base = localdir(document)
          [document.attr("plantuml-includedirs"), attrs["includedirs"]]
            .compact.flat_map { |list| list.split(";") }
            .map(&:strip).reject(&:empty?)
            .map { |dir| ::File.expand_path(dir, base) }
        end

        def validate_source(source)
          match = source.match(/^@start(\w+)/i)
          raise "PlantUML content must start with @start... directive!" if match.nil?

          return if source.downcase.include?("@end#{match[1].downcase}")

          raise "@start#{match[1].downcase} without matching " \
                "@end#{match[1].downcase} in PlantUML!"
        end

        def base_name(source)
          named = source.lines.first.to_s.strip[/\A@start\w+\s+(.+)/i, 1]
          return "plantuml_#{Time.now.strftime('%Y%m%d_%H%M%S_%L')}" unless named

          sanitize(named.gsub(/\A["']|["']\z/, ""))
        end

        def sanitize(name)
          cleaned = name.gsub(/[^\w\-.]/, "_").gsub(/\.{2,}/, ".")
                        .gsub(/_{2,}/, "_")
          cleaned.gsub(/\A[_.-]+(?=.)|(?<=.)[_.-]+\z/, "")
        end

        # Returns [absolute dir that contains _plantuml_images, that
        # subdir's path relative to the document's imagesdir].
        def output_dirs(document)
          localdir = localdir(document)
          raise "Destination directory #{localdir} not writable for PlantUML!" unless ::File.writable?(localdir)

          target = ::Pathname.new(::File.join(localdir, IMAGES_SUBDIR))
          target.mkpath
          base = imagesdir(document, localdir)
          [localdir, target.relative_path_from(::Pathname.new(base)).to_s]
        end

        def localdir(document)
          attrs = document.attributes
          return ::File.dirname(attrs["docfile"]) if attrs["docfile"]

          attrs["docdir"] || attrs["localdir"] || "."
        end

        def imagesdir(document, localdir)
          dir = document.attr("imagesdir")
          return localdir unless dir
          return dir if ::Pathname.new(dir).absolute?

          ::File.expand_path(dir, localdir)
        end

        def image_block(parent, attrs, files, formats)
          through = IMAGE_ATTRS.each_with_object({}) do |key, memo|
            memo[key] = attrs[key] if attrs.key?(key)
          end
          through["target"] = files.first
          if files.length > 1
            through["data-formats"] = formats.join(",")
            through["data-files"] = files.join(",")
          end
          create_image_block(parent, through)
        end
      end
    end
  end
end
