module Rgviz
  class TableBuilder
    def initialize(columns = [])
      @table = Rgviz::Table.new
      columns.each do |column|
        @table.cols << Rgviz::Column.new(column)
      end
    end

    def table
      @table
    end

    def add_row(*values)
      @table.rows << Rgviz::Row.new(
        :c => values.map { |value| Rgviz::Cell.new(:v => value) }
      )
    end
  end
end