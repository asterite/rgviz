Gem::Specification.new do |s|
  s.name = %q{rgviz}
  s.version = "0.46"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ary Borenszweig"]
  s.date = %q{2010-06-08}
  s.description = %q{Google Visualization API Query Language written in Ruby.}
  s.email = %q{aborenszweig@manas.com.ar}
  s.homepage = %q{http://code.google.com/p/rgviz}
  s.require_paths = ["lib"]
  s.files = [
    "lib/rgviz.rb",
    "lib/rgviz/csv_renderer.rb",
    "lib/rgviz/html_renderer.rb",
    "lib/rgviz/lexer.rb",
    "lib/rgviz/memory_executor.rb",
    "lib/rgviz/nodes.rb",
    "lib/rgviz/parser.rb",
    "lib/rgviz/token.rb",
    "lib/rgviz/visitor.rb",
    "lib/rgviz/table.rb",
    "spec/rgviz/lexer_spec.rb",
    "spec/rgviz/parser_spec.rb"
  ]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Google Visualization API Query Language written in Ruby.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3
  end
end

