# frozen_string_literal: true

require "asciidoctor"
require "fileutils"
require "pathname"
require "sirena"
require "sirena/notation/plantuml"
require_relative "plantuml_preprocessor"

module Metanorma
  module Plugin
    module Sirena
      # What the `[plantuml]` block and the `plantuml_image::file.puml[]`
      # block macro share: format selection, include expansion, Sirena
      # rendering, output naming and the emitted image block. The host class
      # is an Asciidoctor processor (it supplies `create_image_block` and
      # `create_listing_block`).
      #
      # Sirena renders SVG only, so `png`, `pdf`, `txt` and `eps` requests are
      # reported and the block falls back to a PlantUML listing, exactly like
      # any other render failure.
      module PlantumlRendering
        KNOWN_FORMATS = %w[png svg pdf txt eps].freeze
        RENDERABLE_FORMATS = %w[svg].freeze
        DEFAULT_FORMAT = "svg"
        IMAGE_ATTRS = %w[id align float title role width height alt].freeze
        IMAGES_SUBDIR = "_plantuml_images"
        MAX_NAME_LENGTH = 100
        # Output names handed out so far, per document, so two diagrams that
        # share a name get distinct files.
        USED_NAMES = ::ObjectSpace::WeakMap.new
        private_constant :USED_NAMES

        private

        # Renders `source` and returns the image block; any failure warns and
        # returns a PlantUML listing of `fallback_text` instead.
        # @param extra_dirs [Array<String>] further include directories
        def render_block(parent, source, attrs, fallback_text: source,
                         extra_dirs: [])
          if parent.document.attr("plantuml-disabled")
            return abort(parent, fallback_text, attrs,
                         "PlantUML processing disabled")
          end

          formats = renderable(parse_formats(attrs, parent.document))
          validate_source(source)
          stem = base_name(parent.document, source)
          image_block(parent, attrs, formats.map do |format|
            generate_file(parent, source, format, attrs, stem, extra_dirs)
          end, formats)
        rescue StandardError => e
          abort(parent, fallback_text, attrs, e.message)
        end

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

        # Drops (with a warning) the formats Sirena cannot produce so the
        # others still render; raises when none is left.
        def renderable(formats)
          kept, dropped = formats.partition { |f| RENDERABLE_FORMATS.include?(f) }
          dropped.each { |f| warn unsupported(f) } unless kept.empty?
          raise unsupported(dropped.first) if kept.empty?

          kept
        end

        def unsupported(format)
          "Sirena renders SVG only; format '#{format}' is unsupported"
        end

        def normalise(format)
          format.to_s.strip.downcase
        end

        def generate_file(parent, source, format, attrs, stem, extra_dirs)
          raise unsupported(format) unless RENDERABLE_FORMATS.include?(format)

          svg = ::Sirena.render(preprocess(source, parent.document, attrs,
                                           extra_dirs))
          localdir, relative = output_dirs(parent.document)
          filename = "#{stem}.#{format}"
          ::File.write(::File.join(localdir, IMAGES_SUBDIR, filename), svg)
          ::File.join(relative, filename)
        end

        def preprocess(source, document, attrs, extra_dirs)
          dirs = [localdir(document), *include_dirs(document, attrs),
                  *extra_dirs]
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

        # The file stem for one diagram: its PlantUML name, sanitised, made
        # unique within the document; a timestamp when it has no usable name.
        def base_name(document, source)
          name = sanitize(::Sirena::Notation::PlantUML::DiagramName
                            .read(source).to_s)
          return "plantuml_#{Time.now.strftime('%Y%m%d_%H%M%S_%L')}" if name.empty?

          unique(document, name)
        end

        def unique(document, name)
          used = (USED_NAMES[document] ||= [])
          candidate = name
          suffix = 1
          candidate = "#{name}_#{suffix += 1}" while used.include?(candidate)
          used << candidate
          candidate
        end

        # The name is untrusted (`../x`, slashes, quotes): only word
        # characters, `-` and `.` survive, so the result stays one file name
        # inside the images directory.
        def sanitize(name)
          cleaned = name.delete_prefix('"').delete_suffix('"')
                        .delete_prefix("'").delete_suffix("'")
                        .gsub(/[^\w\-.]/, "_").gsub(/\.{2,}/, ".")
                        .gsub(/_{2,}/, "_")
          cleaned = cleaned.gsub(/\A[_.-]+(?=.)|(?<=.)[_.-]+\z/, "")
          cleaned = cleaned[0, MAX_NAME_LENGTH]
          cleaned.match?(/\A[.\-_]*\z/) ? "" : cleaned
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
          dir = attrs["docfile"] && ::File.dirname(attrs["docfile"])
          ::File.expand_path(dir || attrs["docdir"] || attrs["localdir"] || ".")
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
