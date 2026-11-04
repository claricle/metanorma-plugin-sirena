# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Metanorma::Plugin::Sirena::PlantumlPreprocessor do
  let(:dir) { Dir.mktmpdir("plantuml-pre") }
  let(:pre) { described_class.new([dir]) }

  after { FileUtils.remove_entry(dir) }

  def write(name, text)
    path = File.join(dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def wrap(*lines)
    ["@startuml", *lines, "@enduml"].join("\n")
  end

  it "includes the first block by default and the N-th by index" do
    write("a.puml", "@startuml\nA -> B\n@enduml\n@startuml\nC -> D\n@enduml\n")

    expect(pre.expand(wrap("!include a.puml"))).to eq(wrap("A -> B"))
    expect(pre.expand(wrap("!include a.puml!1"))).to eq(wrap("C -> D"))
  end

  it "selects a block by its @startuml(id=...)" do
    write("a.puml", "@startuml(id=ONE)\nA -> B\n@enduml\n" \
                    "@startuml(id=TWO)\nC -> D\n@enduml\n")

    expect(pre.expand(wrap("!include a.puml!TWO"))).to eq(wrap("C -> D"))
  end

  it "includes a file without blocks whole, recursively" do
    write("b.puml", "X -> Y")
    write("a.puml", "!include b.puml\nY -> Z")

    expect(pre.expand(wrap("!include a.puml"))).to eq(wrap("X -> Y", "Y -> Z"))
  end

  it "includes every !startsub of the name and drops the markers" do
    write("s.puml", "!startsub S\nA -> A\n!endsub\nB -> B\n" \
                    "!startsub S\nC -> C\n!endsub")

    expect(pre.expand(wrap("!includesub s.puml!S"))).to eq(wrap("A -> A", "C -> C"))
    expect(pre.expand(wrap("!startsub S", "A -> A", "!endsub")))
      .to eq(wrap("A -> A"))
  end

  it "refuses a file outside the directories, a library and a missing file" do
    write("../outside.puml", "A -> B")

    expect { pre.expand(wrap("!include ../outside.puml")) }
      .to raise_error(/not found/)
    expect { pre.expand(wrap("!include <awslib/AWSCommon>")) }
      .to raise_error(/standard library/)
    expect { pre.expand(wrap("!include nope.puml")) }
      .to raise_error(/not found/)
    expect { pre.expand(wrap("!includesub nope.puml")) }
      .to raise_error(/needs a !SUBNAME|not found/)
  end

  it "stops a file that includes itself" do
    write("loop.puml", "!include loop.puml")

    expect { pre.expand(wrap("!include loop.puml")) }
      .to raise_error(/deeper than/)
  end
end
