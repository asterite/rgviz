module Rgviz
  class MemoryExecutor
    def initialize(query, rows, types)
      @query = query
      @rows = rows
      @types = types
      @types_to_indices = {}
      i = 0
      @types.each do |k, v|
        @types_to_indices[k.to_s] = i
        i += 1
      end
      @labels = {}
    end

    def execute(options = {})
      @query = Parser.parse(@query, options) unless @query.kind_of?(Query)
      @table = Table.new

      generate_columns
      filter_rows
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

    def filter_rows
      return unless @query.where


      @rows = @rows.select do |row|
        visitor = EvalWhereVisitor.new @types_to_indices, row
        @query.where.accept visitor
        visitor.true
      end
    end

    def generate_rows
      ag = []
      rows_length = @rows.length
      row_i = 0
      @rows.each do |row|
        r = generate_row row, row_i, rows_length, ag
        @table.rows << r if r
        row_i += 1
      end
      ag.each do |a|
        r = Row.new
        r.c << Cell.new(:v => a)
        @table.rows << r
      end
    end

    def generate_row(row, row_i, rows_length, ag)
      r = Row.new
      found_ag = false
      if @query.select && @query.select.columns && @query.select.columns.length > 0
        i = 0
        @query.select.columns.each do |col|
          v = eval_select col, row, row_i, rows_length, ag[i]
          if col.class == AggregateColumn
            ag[i] = v
            found_ag = true
          else
            r.c << Cell.new(:v => v)
          end
          i += 1
        end
      else
        row.each do |v|
          r.c << Cell.new(:v => v)
        end
      end
      if found_ag
        nil
      else
        r
      end
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

    def eval_select(col, row, row_i, rows_length, ag)
      visitor = EvalSelectVisitor.new @types_to_indices, row, row_i, rows_length, ag
      col.accept visitor
      visitor.value
    end

    class EvalSelectVisitor < Visitor
      attr_reader :value

      def initialize(types_to_indices, row, row_i, rows_length, ag)
        @types_to_indices = types_to_indices
        @row = row
        @row_i = row_i
        @rows_length = rows_length
        @row_i = row_i
        @rows_length = rows_length
        @ag = ag
      end

      def visit_id_column(col)
        i = @types_to_indices[col.name]
        raise "Unknown column #{col}" unless i
        @value = @row[i]
      end

      def visit_number_column(col)
        @value = col.value
      end

      def visit_string_column(col)
        @value = col.value
      end

      def visit_boolean_column(col)
        @value = col.value
      end

      def visit_date_column(col)
        @value = col.value.to_s
      end

      def visit_date_time_column(node)
        @value = node.value.strftime("%Y-%m-%d %H:%M:%S")
      end

      def visit_time_of_day_column(node)
        @value = node.value.strftime("%H:%M:%S")
      end

      def visit_scalar_function_column(node)
        case node.function
        when ScalarFunctionColumn::Sum
          node.arguments[0].accept self; val1 = @value
          node.arguments[1].accept self; val2 = @value
          @value = val1 + val2
        when ScalarFunctionColumn::Difference
          node.arguments[0].accept self; val1 = @value
          node.arguments[1].accept self; val2 = @value
          @value = val1 - val2
        when ScalarFunctionColumn::Product
          node.arguments[0].accept self; val1 = @value
          node.arguments[1].accept self; val2 = @value
          @value = val1 * val2
        when ScalarFunctionColumn::Quotient
          node.arguments[0].accept self; val1 = @value
          node.arguments[1].accept self; val2 = @value
          @value = val1 / val2
        else
        end
        false
      end

      def visit_aggregate_column(col)
        case col.function
        when AggregateColumn::Sum
          col.argument.accept self
          @value += @ag || 0
        when AggregateColumn::Avg
          col.argument.accept self
          @value += @ag || 0
          @value = @value / @rows_length.to_f if @row_i == @rows_length - 1
        when AggregateColumn::Count
          @value = (@ag || 0) + 1
        when AggregateColumn::Max
          col.argument.accept self
          @value = @ag if @ag && @ag > @value
        when AggregateColumn::Min
          col.argument.accept self
          @value = @ag if @ag && @ag < @value
        end
        false
      end
    end

    class EvalWhereVisitor < EvalSelectVisitor
      attr_reader :true

      def initialize(types_to_indices, row)
        @row = row
        @types_to_indices = types_to_indices
        @true = true
      end

      def visit_binary_expression(node)
        node.left.accept self; left = @value
        node.right.accept self; right = @value
        case node.operator
        when BinaryExpression::Gt
          @true = left > right
        when BinaryExpression::Gte
          @true = left >= right
        when BinaryExpression::Lt
          @true = left < right
        when BinaryExpression::Lte
          @true = left <= right
        when BinaryExpression::Eq
          @true = left == right
        when BinaryExpression::Neq
          @true = left != right
        when BinaryExpression::Contains
          @true = !!left[right]
        when BinaryExpression::StartsWith
          @true = left.start_with? right
        when BinaryExpression::EndsWith
          @true = left.end_with? right
        when BinaryExpression::Like
          right.gsub!('%', '.*')
          right.gsub!('_', '.')
          right = Regexp.new right
          @true = !!(left =~ right)
        when BinaryExpression::Matches
          right = Regexp.new "^#{right}$"
          @true = !!(left =~ right)
        end
      end
    end

  end
end
