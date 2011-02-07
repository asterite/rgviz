module Rgviz
  class MemoryExecutor
    def initialize(query, rows, types)
      @query = query
      @rows = rows
      @types = types
      @labels = {}
    end

    def execute(options = {})
      @query = Parser.parse(@query, options) unless @query.kind_of?(Query)
      @table = Table.new

      generate_columns
      generate_rows

      @table
    end

    private

    def generate_columns
      if @query.select && @query.select.columns && @query.select.columns.length > 0
        # Select the specified columns
        i = 0
        @query.select.columns.each do |col|
          col_to_s = col.to_s
          @table.cols << (Column.new :id => column_id(col, i), :type => column_type(col), :label => column_label(col_to_s))
        end
      else
        # Select all columns
        @types.each do |k, v|
          @table.cols << Column.new(:id => k, :type => v, :label => k)
        end
      end
    end

    def generate_rows
      @rows.each do |row|
        @table.rows << generate_row(row)
      end
    end

    def generate_row(row)
      r = Row.new
      if @query.select && @query.select.columns && @query.select.columns.length > 0
        @query.select.columns.each do |col|
          r.c << Cell.new(:v => eval_column(row, col))
        end
      else
        row.each do |v|
          r.c << Cell.new(:v => v)
        end
      end
      r
    end

    def column_id(col, i)
      case col
      when IdColumn
        col.name
      else
        "c#{i}"
      end
    end

    def column_type(col)
      case col
      when IdColumn
        i = 0
        type = @types.select{|x| x[0].to_s == col.to_s}.first
        raise "Unknown column #{col}" unless type
        type[1]
      when NumberColumn
        :number
      when StringColumn
        :string
      when BooleanColumn
        :boolean
      when DateColumn
        :date
      when DateTimeColumn
        :datetime
      when TimeOfDayColumn
        :timeofday
      when ScalarFunctionColumn
        case col.function
        when ScalarFunctionColumn::Now
          :datetime
        when ScalarFunctionColumn::ToDate
          :date
        when ScalarFunctionColumn::Upper, ScalarFunctionColumn::Lower, ScalarFunctionColumn::Concat
          :string
        else
          :number
        end
      when AggregateColumn
        :number
      end
    end

    def column_label(string)
      @labels[string] || string
    end

    def eval_column(row, col)
      visitor = EvalVisitor.new(@types, row)
      col.accept visitor
      visitor.value
    end

    class EvalVisitor < Visitor
      attr_reader :value

      def initialize(types, row)
        @types = types
        @row = row
      end

      def visit_id_column(col)
        i = 0
        @types.each do |k, v|
          if k.to_s == col.name
            @value = @row[i]
            return
          end
          i += 1
        end
        raise "Unknown column #{col}"
      end

      def visit_number_column(col)
        @value = col.value
      end
    end
  end
end
