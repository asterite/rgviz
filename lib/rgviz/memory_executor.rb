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

      process_labels

      generate_columns
      check_has_aggregation
      filter_rows
      group_rows
      sort_rows
      limit_rows
      generate_rows

      @table
    end

    private

    def process_labels
      return unless @query.labels

      @query.labels.each do |label|
        @labels[label.column.to_s] = label.label
      end
    end

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

    def check_has_aggregation
      @has_aggregation = @query.group_by || (@query.select && @query.select.columns && @query.select.columns.any?{|x| x.class == AggregateColumn})
    end

    def filter_rows
      return unless @query.where

      @rows = @rows.select do |row|
        visitor = EvalWhereVisitor.new @types_to_indices, row
        @query.where.accept visitor
        visitor.value
      end
    end

    def group_rows
      if not @query.group_by
        if @has_aggregation
          @rows = [['', @rows]]
        end
        return
      end

      groups = Hash.new{|h, k| h[k] = []}
      @rows.each do |row|
        group = []
        @query.group_by.columns.each do |col|
          visitor = EvalGroupVisitor.new @types_to_indices, row
          col.accept visitor
          group << [col, visitor.value]
        end
        groups[group] << row
      end
      @rows = groups.to_a
    end

    def sort_rows
      return unless @query.order_by

      if @has_aggregation
        @rows.sort! do |row1, row2|
          g1 = row1[0]
          g2 = row2[0]
          @sort = 0
          @query.order_by.sorts.each do |sort|
            g1sc = g1.select{|x| x[0] == sort.column}.first
            if g1sc
              g2sc = g2.select{|x| x[0] == sort.column}.first
              if sort.order == Sort::Asc
                @sort = g1sc[1] <=> g2sc[1]
              else
                @sort = g2sc[1] <=> g1sc[1]
              end
              break unless @sort == 0
            else
              raise "Order by column not found: #{sort.column}"
            end
          end
          @sort
        end
      else
        @rows.sort! do |row1, row2|
          @sort = 0
          @query.order_by.sorts.each do |sort|
            val1 = eval_select sort.column, row1
            val2 = eval_select sort.column, row2
            if sort.order == Sort::Asc
              @sort = val1 <=> val2
            else
              @sort = val2 <=> val1
            end
            break unless @sort == 0
          end
          @sort
        end
      end
    end

    def limit_rows
      return unless @query.limit

      offset = (@query.offset ? (@query.offset - 1) : 0)
      @rows = @rows[offset ... offset + @query.limit]
    end

    def generate_rows
      if @has_aggregation
        @rows.each do |grouping, rows|
          ag = []
          rows_length = rows.length
          row_i = 0
          rows.each do |row|
            r = generate_row row, row_i, rows_length, ag
            @table.rows << r if r
            row_i += 1
          end
          ag.each do |a|
            r = Row.new
            r.c << Cell.new(:v => format_value(a))
            @table.rows << r
          end
        end
      else
        @rows.each do |row|
          r = generate_row row
          @table.rows << r
        end
      end
    end

    def generate_row(row, row_i = nil, rows_length = nil, ag = nil)
      r = Row.new
      found_ag = false
      if @query.select && @query.select.columns && @query.select.columns.length > 0
        i = 0
        @query.select.columns.each do |col|
          v = eval_select col, row, row_i, rows_length, (ag ? ag[i] : nil)
          if col.class == AggregateColumn
            ag[i] = v
            found_ag = true
          else
            r.c << Cell.new(:v => format_value(v))
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

    def format_value(v)
      case v
      when FalseClass, TrueClass, Integer, Float
        v
      when Date
        v.strftime "%Y-%m-%d"
      when Time
        v.strftime "%Y-%m-%d %H:%M:%S"
      else
        v.to_s
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

    def eval_select(col, row, row_i = nil, rows_length = nil, ag = nil)
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
        @value = col.value
      end

      def visit_date_time_column(node)
        @value = node.value
      end

      def visit_time_of_day_column(node)
        @value = node.value.strftime("%H:%M:%S")
      end

      def visit_scalar_function_column(node)
        if node.arguments.length >= 1
          node.arguments[0].accept self; val1 = @value
        end
        if node.arguments.length == 2
          node.arguments[1].accept self; val2 = @value
        end
        case node.function
        when ScalarFunctionColumn::Sum
          @value = val1 + val2
        when ScalarFunctionColumn::Difference
          @value = val1 - val2
        when ScalarFunctionColumn::Product
          @value = val1 * val2
        when ScalarFunctionColumn::Quotient
          @value = val1 / val2
        when ScalarFunctionColumn::Concat
          @value = "#{val1}#{val2}"
        when ScalarFunctionColumn::DateDiff
          @value = (val1 - val2).to_i
        when ScalarFunctionColumn::Year
          @value = val1.year
        when ScalarFunctionColumn::Month
          @value = val1.month
        when ScalarFunctionColumn::Day
          @value = val1.day
        when ScalarFunctionColumn::DayOfWeek
          @value = val1.wday
        when ScalarFunctionColumn::Hour
          @value = val1.hour
        when ScalarFunctionColumn::Minute
          @value = val1.min
        when ScalarFunctionColumn::Second
          @value = val1.sec
        when ScalarFunctionColumn::Quarter
          @value = (val1.month / 3.0).ceil
        when ScalarFunctionColumn::Millisecond
          raise "Millisecond is not implemented"
        when ScalarFunctionColumn::Lower
          @value = val1.downcase
        when ScalarFunctionColumn::Upper
          @value = val1.upcase
        when ScalarFunctionColumn::Now
          @value = Time.now
        when ScalarFunctionColumn::ToDate
          case @value
          when Date
            @value = @value
          when Time
            @value = Date.civil @value.year, @value.month, @value.day
          when Integer
            seconds = @value / 1000
            millis = @value % 1000
            @value = Time.at seconds, millis
            @value = Date.civil @value.year, @value.month, @value.day
          end
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
      def initialize(types_to_indices, row)
        @row = row
        @types_to_indices = types_to_indices
      end

      def visit_aggregate_column(col)
        raise "Aggregation function #{col.function} cannot be used in where clause"
      end

      def visit_binary_expression(node)
        node.left.accept self; left = @value
        node.right.accept self; right = @value
        case node.operator
        when BinaryExpression::Gt
          @value = left > right
        when BinaryExpression::Gte
          @value = left >= right
        when BinaryExpression::Lt
          @value = left < right
        when BinaryExpression::Lte
          @value = left <= right
        when BinaryExpression::Eq
          @value = left == right
        when BinaryExpression::Neq
          @value = left != right
        when BinaryExpression::Contains
          @value = !!left[right]
        when BinaryExpression::StartsWith
          @value = left.start_with? right
        when BinaryExpression::EndsWith
          @value = left.end_with? right
        when BinaryExpression::Like
          right.gsub!('%', '.*')
          right.gsub!('_', '.')
          right = Regexp.new right
          @value = !!(left =~ right)
        when BinaryExpression::Matches
          right = Regexp.new "^#{right}$"
          @value = !!(left =~ right)
        end
        false
      end

      def visit_logical_expression(node)
        values = []
        node.operands.each do |op|
          op.accept self
          values << @value
        end
        case node.operator
        when LogicalExpression::And
          node.operands.each do |op|
            op.accept self
            break unless @value
          end
        when LogicalExpression::Or
          node.operands.each do |op|
            op.accept self
            break if @value
          end
        end
        false
      end

      def visit_unary_expression(node)
        node.operand.accept self
        case node.operator
        when UnaryExpression::Not
          @value = !@value
        when UnaryExpression::IsNull
          @value = @value.nil?
        when UnaryExpression::IsNotNull
          @value = !@value.nil?
        end
        false
      end
    end

    class EvalGroupVisitor < EvalSelectVisitor
      def initialize(types_to_indices, row)
        @row = row
        @types_to_indices = types_to_indices
      end
    end
  end
end
