module Rgviz
  class MemoryExecutor
    def initialize(rows, types)
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

    def execute(query)
      @query = query
      @query = Parser.parse(@query) unless @query.kind_of?(Query)
      @table = Table.new

      process_labels

      check_has_aggregation

      generate_columns

      if @has_aggregation
        filter_and_group_rows
      else
        filter_rows
      end

      sort_rows
      limit_rows
      generate_rows

      @table
    end

    private

    def process_labels
      return unless @query.labels

      @query.labels.each do |label|
        @labels[label.column] = label.label
      end
    end

    def check_has_aggregation
      @has_aggregation = @query.group_by || @query.pivot || (@query.select? && @query.select.columns.any?{|x| x.class == AggregateColumn})
    end

    def generate_columns
      if @query.select?
        # Select the specified columns
        i = 0
        @query.select.columns.each do |col|
          @table.cols << (Column.new :id => column_id(col, i), :type => column_type(col), :label => column_label(col))
          i += 1
        end
      else
        # Select all columns
        @table.cols = @types.map{|k, v| Column.new :id => k, :type => v, :label => k}
      end
    end

    def filter_rows
      return unless @query.where

      @rows = @rows.reject{|row| row_is_filtered? row}
    end

    def row_is_filtered?(row)
      visitor = EvalWhereVisitor.new @types_to_indices, row
      @query.where.accept visitor
      !visitor.value
    end

    def filter_and_group_rows
      if !@query.group_by && !@query.pivot
        @rows = [[nil, @rows]] if @has_aggregation
        return
      end

      group_columns = []
      group_columns += @query.group_by.columns if @query.group_by
      group_columns += @query.pivot.columns if @query.pivot

      groups = Hash.new{|h, k| h[k] = []}
      @rows.each do |row|
        next if @query.where && row_is_filtered?(row)

        group = group_columns.map{|col| group_row row, col}
        groups[group] << row
      end
      @rows = groups.to_a
    end

    def group_row(row, col)
      visitor = EvalGroupVisitor.new @types_to_indices, row
      col.accept visitor
      [col, visitor.value]
    end

    def sort_rows
      return unless @query.order_by

      if @has_aggregation
        sort_aggregated_rows
        return
      end

      @rows.sort! do |row1, row2|
        @sort = 0
        @query.order_by.sorts.each do |sort|
          val1 = eval_select sort.column, row1
          val2 = eval_select sort.column, row2
          @sort = sort.order == Sort::Asc ? val1 <=> val2 : val2 <=> val1
          break unless @sort == 0
        end
        @sort
      end
    end

    def sort_aggregated_rows
      @rows.sort! do |row1, row2|
        g1 = row1[0]
        g2 = row2[0]
        @sort = 0
        @query.order_by.sorts.each do |sort|
          g1sc = g1.select{|x| x[0] == sort.column}.first
          if g1sc
            g2sc = g2.select{|x| x[0] == sort.column}.first
            @sort = sort.order == Sort::Asc ? g1sc[1] <=> g2sc[1] : g2sc[1] <=> g1sc[1]
            break unless @sort == 0
          else
            raise "Order by column not found: #{sort.column}"
          end
        end
        @sort
      end
    end

    def limit_rows
      return unless @query.limit

      offset = (@query.offset ? (@query.offset - 1) : 0)
      @rows = @rows[offset ... offset + @query.limit]
    end

    def generate_rows
      if !@has_aggregation
        @table.rows = @rows.map{|row| generate_row row}
        return
      end

      rows = generate_aggregated_rows

      if !@query.pivot
        rows_to_table rows
        return
      end

      uniq_pivots = pivot_rows rows
      pivot_cols uniq_pivots
    end

    def pivot_rows(rows)
      # This is grouping => pivot => [selections]
      fin = if RUBY_VERSION.start_with?("1.8")
        if defined? ActiveSupport::OrderedHash
          ActiveSupport::OrderedHash.new
        else
          SimpleOrderedHash.new
        end
      else
        Hash.new
      end

      # The uniq pivot values
      uniq_pivots = []

      selection_indices = []

      i = 0
      @query.select.columns.each do |col|
        if !@query.group_by || !@query.group_by.columns.include?(col)
          selection_indices << i
        end
        i += 1
      end

      # Fill fin and uniq_pivots
      rows.each do |group, row|
        grouped_by = []
        pivots = []

        # The grouping key of this result
        grouped_by = group.select{|g| @query.group_by && @query.group_by.columns.include?(g[0])}

        # The pivots of this result
        pivots = group.select{|g| @query.pivot.columns.include?(g[0])}

        # The selections of this result
        selections = selection_indices.map{|i| row[i]}

        uniq_pivots << pivots unless uniq_pivots.include? pivots

        # Now put all this info into fin
        fin[grouped_by] = {} unless fin[grouped_by]
        fin[grouped_by][pivots] = selections
      end

      # Sort the uniq pivots so the results will be sorted for a human
      uniq_pivots = uniq_pivots.sort_by{|a| a.map{|x| x[1]}.to_s}

      # Create the rows
      fin.each do |key, value|
        row = Row.new
        @table.rows << row

        pivot_i = 0

        @query.select.columns.each do |col|
          if @query.group_by && @query.group_by.columns.include?(col)
            matching_col = key.select{|x| x[0] == col}.first
            row.c << Cell.new(:v => format_value(matching_col[1]))
          else
            uniq_pivots.each do |uniq_pivot|
              u = value[uniq_pivot]
              row.c << Cell.new(:v => u ? format_value(u[pivot_i]) : nil)
            end
            pivot_i += 1
          end
        end
      end

      uniq_pivots
    end

    def pivot_cols(uniq_pivots)
      return unless uniq_pivots.length > 0

      new_cols = []
      i = 0
      @query.select.columns.each do |col|
        id = "c#{i}"
        label = column_label col
        type = column_type col

        if @query.group_by && @query.group_by.columns.include?(col)
          new_cols << Column.new(:id => id, :label => label, :type => type)
          i += 1
        else
          uniq_pivots.each do |uniq_pivot|
            new_cols << Column.new(:id => "c#{i}", :label => "#{uniq_pivot.map{|x| x[1]}.join ', '} #{label}", :type => type)
            i += 1
          end
        end
      end
      @table.cols = new_cols
    end

    def rows_to_table(rows)
      @table.rows = rows.map do |grouping, cols|
        r = Row.new
        r.c = cols.map do |value|
          Cell.new :v => format_value(value)
        end
        r
      end
    end

    def generate_aggregated_rows
      @rows.map do |grouping, rows|
        ag = []
        rows_length = rows.length
        row_i = 0
        rows.each do |row|
          compute_row_aggregation row, row_i, rows_length, ag
          row_i += 1
        end
        [grouping, ag]
      end
    end

    def generate_row(row)
      r = Row.new
      if @query.select?
        r.c = @query.select.columns.map{|col| Cell.new :v => format_value(eval_select col, row)}
      else
        r.c = row.map{|v| Cell.new :v => format_value(v)}
      end
      r
    end

    def compute_row_aggregation(row, row_i, rows_length, ag)
      raise "Must specify a select clause if group by or pivot specified" unless @query.select?

      i = 0
      @query.select.columns.each do |col|
        ag[i] = eval_aggregated_select col, row, row_i, rows_length, ag[i]
        i += 1
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
        type = @types.select{|x| x[0].to_s == col.name}.first
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

    def column_label(col)
      @labels[col] || col.to_s
    end

    def eval_select(col, row)
      eval_aggregated_select col, row, nil, nil, nil
    end

    def eval_aggregated_select(col, row, row_i, rows_length, ag)
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
            @value = Time.utc 1970, 1, 1, 0, 0, 0
            @value += seconds + millis / 1000.0
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

      def visit_aggregate_column(node)
        raise "Can't use aggregation functions in group by"
      end
    end

    class SimpleOrderedHash
      def initialize
        @keys = []
        @hash = Hash.new
      end

      def [](key)
        @hash[key]
      end

      def []=(key, value)
        if !@keys.include?(key)
          @keys << key
        end
        @hash[key] = value
      end

      def each
        @keys.each do |key|
          yield key, @hash[key]
        end
      end
    end
  end
end
