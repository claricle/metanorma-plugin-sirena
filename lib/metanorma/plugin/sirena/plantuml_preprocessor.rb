# frozen_string_literal: true

module Metanorma
  module Plugin
    module Sirena
      # Expands PlantUML's file-inclusion directives before the source is
      # handed to Sirena, which sees one self-contained diagram.
      #
      # Handles `!include`, `!include_many`, `!include_once`, `!includesub`
      # and the `!startsub NAME` / `!endsub` markers, with PlantUML's
      # selectors on the file: `file!N` (the N-th `@start...` block, from 0),
      # `file!ID` (the block opened by `@startuml(id=ID)`) and, for
      # `!includesub`, `file!SUB`. Files are searched in `dirs` only, and a
      # file outside them is refused. Standard-library (`<lib/name>`) and URL
      # includes need PlantUML's bundled libraries or the network and are
      # refused by name.
      class PlantumlPreprocessor
        MAX_DEPTH = 10
        INCLUDE = /\A!(include(?:_many|_once|sub)?)[ \t]+(.+?)[ \t]*\z/i
        START_BLOCK = /\A@start\w+(?:\((?:.*?\bid=)?([^)=]*?)\))?/i
        END_BLOCK = /\A@end\w+/i
        STARTSUB = /\A!startsub[ \t]+(\w+)[ \t]*\z/i
        ENDSUB = /\A!endsub\b/i
        private_constant :MAX_DEPTH, :INCLUDE, :START_BLOCK, :END_BLOCK,
                         :STARTSUB, :ENDSUB

        # @param dirs [Array<String>] absolute directories searched, in order
        def initialize(dirs)
          @dirs = dirs.map { |dir| ::File.expand_path(dir) }.uniq
        end

        # @param source [String] a `@start... @end...` PlantUML diagram
        # @return [String] the diagram with every include expanded and the
        #   `!startsub`/`!endsub` markers removed
        def expand(source)
          expand_lines(source.lines.map(&:chomp), 0).join("\n")
        end

        private

        def expand_lines(lines, depth)
          lines.flat_map do |line|
            text = line.strip
            if (match = INCLUDE.match(text))
              included(match[1].downcase, match[2], depth)
            elsif STARTSUB.match?(text) || ENDSUB.match?(text)
              []
            else
              [line]
            end
          end
        end

        def included(directive, target, depth)
          raise "PlantUML !include nesting is deeper than #{MAX_DEPTH}" if depth >= MAX_DEPTH

          path, selector = split_target(target)
          lines = ::File.read(resolve(path)).lines.map(&:chomp)
          body = if directive == "includesub"
                   sub_lines(lines, selector, target)
                 else
                   block_lines(lines, selector, target)
                 end
          expand_lines(body, depth + 1)
        end

        def split_target(target)
          path, selector = target.split("!", 2)
          [path.strip, selector&.strip]
        end

        def resolve(path)
          if path.start_with?("<") || path.match?(%r{\A\w+://})
            raise "PlantUML !include #{path} needs PlantUML's standard " \
                  "library or the network, which Sirena does not have"
          end

          @dirs.each do |dir|
            candidate = ::File.expand_path(path, dir)
            return candidate if inside?(candidate) && ::File.file?(candidate)
          end
          raise "PlantUML !include #{path} not found in includedirs"
        end

        def inside?(candidate)
          real = ::File.realpath(candidate)
          @dirs.any? do |dir|
            real.start_with?("#{::File.realpath(dir)}#{::File::SEPARATOR}")
          end
        rescue SystemCallError
          false
        end

        # The lines of the selected `@start...` block, or of the whole file
        # when it holds no block.
        def block_lines(lines, selector, target)
          blocks = split_blocks(lines)
          return lines if blocks.empty?

          chosen = pick_block(blocks, selector, target)
          chosen[:lines]
        end

        def split_blocks(lines)
          blocks = []
          current = nil
          lines.each do |line|
            text = line.strip
            if (match = START_BLOCK.match(text))
              current = { id: match[1], lines: [] }
            elsif END_BLOCK.match?(text)
              blocks << current if current
              current = nil
            elsif current
              current[:lines] << line
            end
          end
          blocks
        end

        def pick_block(blocks, selector, target)
          return blocks.first if selector.nil?

          if selector.match?(/\A\d+\z/)
            blocks[selector.to_i]
          else
            blocks.find { |block| block[:id] == selector }
          end || raise("PlantUML !include #{target}: no such block")
        end

        def sub_lines(lines, name, target)
          raise "PlantUML !includesub #{target} needs a !SUBNAME" if name.nil?

          found = false
          kept = []
          open = false
          lines.each do |line|
            text = line.strip
            if (match = STARTSUB.match(text))
              open = match[1] == name
              found ||= open
            elsif ENDSUB.match?(text)
              open = false
            elsif open
              kept << line
            end
          end
          raise "PlantUML !includesub #{target}: no such sub-block" unless found

          kept
        end
      end
    end
  end
end
