require 'time'
require 'date'

module Rgviz
  class Parser < Lexer
    def initialize(string)
      super
      @query = Query.new
      next_token
    end

    def self.parse(string)
      Parser.new(string).parse
    end

    def parse
      parse_select
      parse_where
      parse_group_by
      parse_pivot
      parse_order_by
      parse_limit
      parse_offset
      parse_label
      parse_format
      parse_options

      raise ParseException.new("Expecting end of query, got: #{@token.string}") if @token.value != Token::EOF
      @query
    end

    def parse_select
      return if not token_is! Token::Select

      @query.select = Select.new

      return if token_is! Token::STAR

      parse_columns @query.select.columns

      raise ParseException.new("Expecting select columns") if @query.select.columns.empty?
    end

    def parse_where
      return if not token_is! Token::Where

      @query.where = Where.new parse_expression
    end

    def parse_group_by
      return if not token_is! Token::Group
      check! Token::By

      @query.group_by = GroupBy.new
      @query.group_by.columns = parse_columns

      raise ParseException.new("Expecting group by columns") if @query.group_by.columns.empty?
    end

    def parse_pivot
      return if not token_is! Token::Pivot

      @query.pivot = Pivot.new
      @query.pivot.columns = parse_columns

      raise ParseException.new("Expecting pivot columns") if @query.pivot.columns.empty?
    end

    def parse_order_by
      return if not token_is! Token::Order
      check! Token::By

      @query.order_by = OrderBy.new
      @query.order_by.sorts = parse_sorts

      raise ParseException.new("Expecting order by columns") if @query.order_by.sorts.empty?
    end

    def parse_limit
      return if not token_is! Token::Limit

      check Token::INTEGER

      @query.limit = @token.number
      next_token
    end

    def parse_offset
      return if not token_is! Token::Offset

      check Token::INTEGER

      @query.offset = @token.number
      next_token
    end

    def parse_label
      return if not token_is! Token::Label

      @query.labels = []

      column = parse_column
      raise ParseException.new("Expecting label") unless column

      check Token::STRING
      @query.labels << Label.new(column, @token.string)
      next_token

      while token_is! Token::COMMA
        column = parse_column
        break unless column

        check Token::STRING
        @query.labels << Label.new(column, @token.string)
        next_token
      end

      raise ParseException.new("Expecting label") if @query.labels.empty?
    end

    def parse_format
      return if not token_is! Token::Format

      @query.formats = []

      column = parse_column
      raise ParseException.new("Expecting format") unless column

      check Token::STRING
      @query.formats << Format.new(column, @token.string)
      next_token

      while token_is! Token::COMMA
        column = parse_column
        break unless column

        check Token::STRING
        @query.formats << Format.new(column, @token.string)
        next_token
      end

      raise ParseException.new("Expecting format") if @query.formats.empty?
    end

    def parse_options
      return if not token_is! Token::Options

      @query.options = Options.new

      while true
        case @token.value
        when Token::NoFormat
          @query.options.no_format = true
          next_token
        when Token::NoValues
          @query.options.no_values = true
          next_token
        else
          break
        end
      end

      raise ParseException.new("Expecting option") if !@query.options.no_format && !@query.options.no_values
      raise ParseException.new("Unknown option #{@token.string}") if @token.value != Token::EOF
    end

    def parse_sorts
      sorts = []

      column = parse_column
      return sorts unless column

      order = parse_sort_order

      sorts << Sort.new(column, order)
      while token_is! Token::COMMA
        column = parse_column
        break unless column

        order = parse_sort_order
        sorts << Sort.new(column, order)
      end
      sorts
    end

    def parse_sort_order
      if token_is! Token::Asc
        Sort::Asc
      elsif token_is! Token::Desc
        Sort::Desc
      else
        Sort::Asc
      end
    end

    def parse_expression
      parse_or_expression
    end

    def parse_or_expression
      left = parse_and_expression
      return left unless token_is? Token::Or

      operands = [left]
      while true
        if token_is! Token::Or
          operands << parse_and_expression
        else
          return LogicalExpression.new(LogicalExpression::Or, operands)
        end
      end
    end

    def parse_and_expression
      left = parse_not_expression
      return left unless token_is? Token::And

      operands = [left]
      while true
        if token_is! Token::And
          operands << parse_not_expression
        else
          return LogicalExpression.new(LogicalExpression::And, operands)
        end
      end
    end

    def parse_not_expression
      if token_is! Token::Not
        operand = parse_primary_expression
        UnaryExpression.new UnaryExpression::Not, operand
      else
        parse_primary_expression
      end
    end

    def parse_primary_expression
      case @token.value
      when Token::LPAREN
        next_token
        exp = parse_expression
        check! Token::RPAREN
        return exp
      else
        left = parse_column
        raise ParseException.new("Expecting left exp") unless left

        case @token.value
        when Token::Is
          next_token
          if token_is! Token::Not
            check! Token::Null
            return UnaryExpression.new(UnaryExpression::IsNotNull, left)
          elsif token_is! Token::Null
            return UnaryExpression.new(UnaryExpression::IsNull, left)
          end
        when Token::EQ, Token::NEQ, Token::LT, Token::LTE, Token::GT, Token::GTE,
             Token::Contains, Token::Matches, Token::Like
          operator = @token.value
          next_token
          right = parse_column
          raise ParseException.new("Expecting right exp") unless right
          return BinaryExpression.new(left, operator, right)
        when Token::Starts, Token::Ends
          operator = "#{@token.value} with".to_sym
          next_token
          check! Token::With
          right = parse_column
          raise ParseException.new("Expecting right exp") unless right
          return BinaryExpression.new(left, operator, right)
        else
          raise ParseException.new("Expecting comparison")
        end
      end
    end

    def parse_columns(columns = [])
      column = parse_column
      return columns unless column

      columns << column
      while token_is! Token::COMMA
        column = parse_column
        break unless column
        columns << column
      end
      columns
    end

    def parse_column
      parse_arithmetic_expression
    end

    def parse_arithmetic_expression
      parse_summation_or_substraction
    end

    def parse_summation_or_substraction
      left = parse_multiplication_or_divition
      while true
        case @token.value
        when Token::PLUS
          next_token
          right = parse_multiplication_or_divition
          left = ScalarFunctionColumn.new ScalarFunctionColumn::Sum, left, right
        when Token::MINUS
          next_token
          right = parse_multiplication_or_divition
          left = ScalarFunctionColumn.new ScalarFunctionColumn::Difference, left, right
        else
          return left
        end
      end
    end

    def parse_multiplication_or_divition
      left = parse_atomic_column
      while true
        case @token.value
        when Token::STAR
          next_token
          right = parse_atomic_column
          left = ScalarFunctionColumn.new ScalarFunctionColumn::Product, left, right
        when Token::SLASH
          next_token
          right = parse_atomic_column
          left = ScalarFunctionColumn.new ScalarFunctionColumn::Quotient, left, right
        else
          return left
        end
      end
    end

    def parse_atomic_column
      case @token.value
      when Token::ID
        return value_column(IdColumn.new(@token.string))
      when Token::Contains, Token::Starts, Token::Ends, Token::With,
           Token::Matches, Token::Like, Token::NoValues, Token::NoFormat,
           Token::Is, Token::Null
        return value_column(IdColumn.new(@token.string))
      when Token::PLUS
        next_token
        check Token::INTEGER, Token::DECIMAL
        return value_column(NumberColumn.new(@token.number))
      when Token::MINUS
        next_token
        check Token::INTEGER, Token::DECIMAL
        return value_column(NumberColumn.new(-@token.number))
      when Token::INTEGER, Token::DECIMAL
        return value_column(NumberColumn.new(@token.number))
      when Token::LPAREN
        next_token
        column = parse_column
        check! Token::RPAREN
        return column
      when Token::STRING
        return value_column(StringColumn.new(@token.string))
      when Token::False
        return value_column(BooleanColumn.new(false))
      when Token::True
        return value_column(BooleanColumn.new(true))
      when Token::Date
        next_token
        check Token::STRING
        return value_column(DateColumn.new(parse_date(@token.string)))
      when Token::DateTime
        next_token
        check Token::STRING
        return value_column(DateTimeColumn.new(parse_time(@token.string)))
      when Token::TimeOfDay
        next_token
        check Token::STRING
        return value_column(TimeOfDayColumn.new(parse_time(@token.string)))
      when Token::Avg, Token::Count, Token::Min, Token::Max, Token::Sum
        function = @token.value
        string = @token.string
        next_token
        if token_is! Token::LPAREN
          column = parse_column
          check! Token::RPAREN
          return AggregateColumn.new(function, column)
        else
          return IdColumn.new(string)
        end
      when Token::Year, Token::Month, Token::Day,
           Token::Hour, Token::Minute, Token::Second, Token::Millisecond,
           Token::Now, Token::DateDiff, Token::Lower, Token::Upper,
           Token::Quarter, Token::DayOfWeek, Token::ToDate, Token::Concat,
           Token::Round,Token::Floor
        function = @token.value
        string = @token.string
        next_token
        if token_is! Token::LPAREN
          columns = parse_columns
          check! Token::RPAREN
          return ScalarFunctionColumn.new(function, *columns)
        else
          return IdColumn.new(string)
        end
      end
      nil
    end

    def value_column(col)
      column = col
      next_token
      return column
    end

    def token_is?(token_value)
      @token.value == token_value
    end

    def token_is!(token_value)
      if @token.value == token_value
        next_token
        true
      else
        false
      end
    end

    def check(*token_values)
      raise ParseException.new("Expecting token #{token_values}") unless token_values.any?{|value| @token.value == value}
    end

    def check!(*token_values)
      check *token_values
      next_token
    end

  protected
    def parse_date(date_string)
      Date.parse(date_string)
    end

    def parse_time(time_string)
      Time.parse(time_string)
    end
  end
end
