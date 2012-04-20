module Rgviz
  class Query
    attr_accessor :select
    attr_accessor :where
    attr_accessor :group_by
    attr_accessor :pivot
    attr_accessor :order_by
    attr_accessor :limit
    attr_accessor :offset
    attr_accessor :labels
    attr_accessor :formats
    attr_accessor :options

    def select?
      @select && @select.columns && @select.columns.length > 0
    end

    def accept(visitor)
      if visitor.visit_query self
        select.accept visitor if select
        where.accept visitor if where
        group_by.accept visitor if group_by
        pivot.accept visitor if pivot
        order_by.accept visitor if order_by
        labels.each{|x| x.accept visitor} if labels
        formats.each{|x| x.accept visitor} if formats
      end
      visitor.end_visit_query self
    end

    def to_s
      str = ''
      if select
        if select.columns.empty?
          str << "select * "
        else
          str << "select #{select.to_s} "
        end
      end
      str << "where #{where} " if where
      str << "group by #{group_by} " if group_by
      str << "pivot #{pivot} " if pivot
      str << "order by #{order_by} " if order_by
      str << "limit #{limit} " if limit
      str << "offset #{offset} " if offset
      str << "label #{labels.map(&:to_s).join(', ')} " if labels
      str << "format #{formats.map(&:to_s).join(', ')} " if formats
      str << "options #{options} " if options
      str.strip
    end
  end

  class ColumnsContainer
    attr_accessor :columns

    def initialize
      @columns = []
    end

    def to_s
      @columns.map(&:to_s).join(', ')
    end
  end

  class Select < ColumnsContainer
    def accept(visitor)
      if visitor.visit_select(self)
        columns.each{|x| x.accept visitor}
      end
      visitor.end_visit_select self
    end
  end

  class GroupBy < ColumnsContainer
    def accept(visitor)
      if visitor.visit_group_by(self)
        columns.each{|x| x.accept visitor}
      end
      visitor.end_visit_group_by self
    end
  end

  class Pivot < ColumnsContainer
    def accept(visitor)
      if visitor.visit_pivot(self)
        columns.each{|x| x.accept visitor}
      end
      visitor.end_visit_pivot self
    end
  end

  class OrderBy
    attr_accessor :sorts

    def initialize
      @sorts = []
    end

    def accept(visitor)
      if visitor.visit_order_by(self)
        sorts.each{|x| x.accept visitor}
      end
      visitor.end_visit_order_by self
    end

    def to_s
      @sorts.map(&:to_s).join(', ')
    end
  end

  class Sort

    Asc = Token::Asc
    Desc = Token::Desc

    attr_accessor :column
    attr_accessor :order

    def initialize(column, order)
      @column = column
      @order = order
    end

    def accept(visitor)
      if visitor.visit_sort(self)
        column.accept visitor
      end
      visitor.end_visit_sort self
    end

    def to_s
      "#{column} #{order}"
    end
  end

  class Where
    attr_accessor :expression

    def initialize(expression)
      @expression = expression
    end

    def accept(visitor)
      if visitor.visit_where(self)
        expression.accept visitor
      end
      visitor.end_visit_where self
    end

    def to_s
      @expression.to_s
    end
  end

  class Label
    attr_accessor :column
    attr_accessor :label

    def initialize(column, label)
      @column = column
      @label = label
    end

    def accept(visitor)
      if visitor.visit_label(self)
        column.accept visitor
      end
      visitor.end_visit_label self
    end

    def to_s
      "#{column} `#{label}`"
    end
  end

  class Format
    attr_accessor :column
    attr_accessor :pattern

    def initialize(column, pattern)
      @column = column
      @pattern = pattern
    end

    def accept(visitor)
      if visitor.visit_format(self)
        column.accept visitor
      end
      visitor.end_visit_format self
    end

    def to_s
      "#{column} `#{pattern}`"
    end
  end

  class Options

    attr_accessor :no_values
    attr_accessor :no_format

    def to_s
      s = ''
      s += 'no_values ' if @no_values
      s += 'no_format ' if @no_format
      s.strip
    end

  end

  class LogicalExpression
    And = Token::And
    Or = Token::Or

    attr_accessor :operator
    attr_accessor :operands

    def initialize(operator, operands)
      @operator = operator
      @operands = operands
    end

    def accept(visitor)
      if visitor.visit_logical_expression(self)
        operands.each{|x| x.accept visitor}
      end
      visitor.end_visit_logical_expression self
    end

    def to_s
      operands.map(&:to_s).join(" #{operator} ")
    end

  end

  class BinaryExpression
    Contains = Token::Contains
    EndsWith = :'ends with'
    Eq = Token::EQ
    Gt = Token::GT
    Gte = Token::GTE
    Like = Token::Like
    Lt = Token::LT
    Lte = Token::LTE
    Matches = Token::Matches
    Neq = Token::NEQ

    StartsWith = :'starts with'

    attr_accessor :operator
    attr_accessor :left
    attr_accessor :right

    def initialize(left, operator, right)
      @left = left
      @operator = operator
      @right = right
    end

    def accept(visitor)
      if visitor.visit_binary_expression(self)
        left.accept visitor
        right.accept visitor
      end
      visitor.end_visit_binary_expression self
    end

    def to_s
      "#{left} #{operator} #{right}"
    end
  end

  class UnaryExpression
    Not = Token::Not
    IsNull = :'is null'
    IsNotNull = :'is not null'

    attr_accessor :operand
    attr_accessor :operator

    def initialize(operator, operand)
      @operator = operator
      @operand = operand
    end

    def accept(visitor)
      if visitor.visit_unary_expression(self)
        operand.accept visitor
      end
      visitor.end_visit_unary_expression self
    end

    def to_s
      if operator == Not
        "not #{operand}"
      else
        "#{operand} #{operator}"
      end
    end
  end

  class IdColumn
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def accept(visitor)
      visitor.visit_id_column(self)
      visitor.end_visit_id_column self
    end

    def hash
      @name.hash
    end

    def eql?(other)
      other.class == IdColumn && other.name == @name
    end

    alias_method :==, :eql?

    def to_s
      @name
    end
  end

  class ValueColumn
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def hash
      @value.hash
    end

    def eql?(other)
      other.class == self.class && other.value == @value
    end

    alias_method :==, :eql?

    def to_s
      value.to_s
    end
  end

  class NumberColumn < ValueColumn
    def accept(visitor)
      visitor.visit_number_column(self)
      visitor.end_visit_number_column self
    end
  end

  class StringColumn < ValueColumn
    def accept(visitor)
      visitor.visit_string_column(self)
      visitor.end_visit_string_column self
    end

    def to_s
      "'#{value}'"
    end
  end

  class BooleanColumn < ValueColumn
    def accept(visitor)
      visitor.visit_boolean_column(self)
      visitor.end_visit_boolean_column self
    end
  end

  class DateColumn < ValueColumn
    def accept(visitor)
      visitor.visit_date_column(self)
      visitor.end_visit_date_column self
    end

    def to_s
      "date '#{value.to_s}'"
    end
  end

  class DateTimeColumn < ValueColumn
    def accept(visitor)
      visitor.visit_date_time_column(self)
      visitor.end_visit_date_time_column self
    end

    def to_s
      "datetime '" + value.strftime("%Y-%m-%d %H:%M:%S") + "'"
    end
  end

  class TimeOfDayColumn < ValueColumn
    def accept(visitor)
      visitor.visit_time_of_day_column(self)
      visitor.end_visit_time_of_day_column self
    end

    def to_s
      "timeofday '" + value.strftime("%H:%M:%S") + "'"
    end
  end

  class ScalarFunctionColumn

    Concat = Token::Concat
    DateDiff = Token::DateDiff
    Day = Token::Day
    DayOfWeek = Token::DayOfWeek
    Difference = Token::MINUS
    Hour = Token::Hour
    Lower = Token::Lower
    Millisecond = Token::Millisecond
    Minute = Token::Minute
    Month = Token::Month
    Now = Token::Now
    Product = Token::STAR
    Quarter = Token::Quarter
    Quotient = Token::SLASH
    Second = Token::Second
    Sum = Token::PLUS
    ToDate = Token::ToDate
    Upper = Token::Upper
    Year = Token::Year

    attr_accessor :function
    attr_accessor :arguments

    def initialize(function, *arguments)
      @function = function
      @arguments = arguments
    end

    def accept(visitor)
      if visitor.visit_scalar_function_column(self)
        arguments.each{|x| x.accept visitor}
      end
      visitor.end_visit_scalar_function_column self
    end

    def hash
      return @hash if @hash
      @hash = 1
      @hash = @hash * 31 + @function.hash
      @arguments.each do |arg|
        @hash = @hash * 31 + arg.hash
      end
      @hash
    end

    def eql?(other)
      other.class == ScalarFunctionColumn && other.function == @function && other.arguments == @arguments
    end

    alias_method :==, :eql?

    def to_s
      case function
      when Sum, Difference, Product, Quotient
        "#{arguments[0].to_s} #{function} #{arguments[1].to_s}"
      else
        "#{function}(#{arguments.map(&:to_s).join(', ')})"
      end
    end
  end

  class AggregateColumn

    Avg = Token::Avg
    Count = Token::Count
    Max = Token::Max
    Min = Token::Min
    Sum = Token::Sum

    attr_accessor :function
    attr_accessor :argument

    def initialize(function, argument)
      @function = function
      @argument = argument
    end

    def accept(visitor)
      if visitor.visit_aggregate_column(self)
        argument.accept visitor
      end
      visitor.end_visit_aggregate_column self
    end

    def hash
      return @hash if @hash
      @hash = 1
      @hash = @hash * 31 + @function.hash
      @hash = @hash * 31 + @argument.hash
      @hash
    end

    def eql?(other)
      other.class == ScalarFunctionColumn && other.function == @function && other.arguments == @arguments
    end

    alias_method :==, :eql?

    def to_s
      "#{function}(#{argument})"
    end
  end
end
