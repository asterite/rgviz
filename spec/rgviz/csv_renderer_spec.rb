require 'rgviz'

include Rgviz

describe CsvRenderer do
  it "renders two rows" do
    table = Table.new
    table.cols << Column.new(:label => 'Title 1')
    table.cols << Column.new(:label => 'Title 2')

    table.rows << Row.new.tap do |r|
      r.c << Cell.new(:v => 'one')
      r.c << Cell.new(:v => 'two')
    end
    table.rows << Row.new.tap do |r|
      r.c << Cell.new(:v => 'three')
      r.c << Cell.new(:v => 'four')
    end

    actual = CsvRenderer.render table
    actual.should eq("Title 1,Title 2\none,two\nthree,four")
  end
end
