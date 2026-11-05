# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "metanorma-plugin-sirena gem entry point" do
  let(:lib) { File.expand_path("../lib", __dir__) }

  def run_ruby(code)
    Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", code)
  end

  it "loads the plugin when required by gem name" do
    out, status = run_ruby(<<~RUBY)
      require "metanorma-plugin-sirena"
      puts defined?(Metanorma::Plugin::Sirena::PlantumlBlockProcessor).inspect
    RUBY

    expect(status).to be_success, out
    expect(out.lines.last.strip).to eq('"constant"')
  end

  it "renders a [plantuml] block through Sirena after a gem-name require" do
    out, status = run_ruby(<<~RUBY)
      require "metanorma-plugin-sirena"
      require "asciidoctor"
      require "tmpdir"
      Dir.chdir(Dir.mktmpdir)
      html = Asciidoctor.convert("[plantuml]\\n....\\n@startuml\\nA -> B\\n@enduml\\n....\\n", safe: :unsafe)
      svg = Dir["_plantuml_images/*.svg"].map { |f| File.read(f) }.join
      puts html.include?("_plantuml_images/") && svg.include?("<svg") && !svg.include?("<?plantuml")
    RUBY

    expect(status).to be_success, out
    expect(out.lines.last.strip).to eq("true")
  end
end
