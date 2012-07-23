require 'rgviz'

include Rgviz

describe Parser do
  def parse(string)
    Parser.parse(string)
  end
  
  def parse_select_single_column(string)
    query = parse "select #{string}"
    select = query.select
    select.columns.length.should == 1
    
    select.columns[0]
  end
  
  def parse_where(string)
    query = parse "where #{string}"
    query.where.expression
  end
  
  def self.it_parses_as_identifier(str)
    it "parses #{str} as identifier" do
      col = parse_select_single_column "#{str}" 
      col.should be_a_kind_of IdColumn
      col.name.should == "#{str}"
    end
  end
  
  def self.it_parses_columns_container(str, method)
    it "parses #{str}" do
      query = parse "#{str} foo"
      cols = query.send method
      cols.columns.length == 1
      cols.columns[0].should be_a_kind_of IdColumn
      cols.columns[0].name.should == 'foo'
    end
  end
  
  def self.it_raises_on(str)
    it "raises on #{str}" do
      lambda { parse "#{str}" }.should raise_error(ParseException)
    end
  end

  it "parses empty" do
    query = parse ''
    query.select.should be_nil
  end

  it "parses select all" do
    query = parse 'select *'
    select = query.select
    select.columns.should be_empty
  end
  
  it "parses select simple columns" do
    query = parse 'select one, two, three'
    select = query.select
    
    select.columns.length.should == 3
    
    ['one', 'two', 'three'].each_with_index do |name, i|
      select.columns[i].should be_a_kind_of IdColumn
      select.columns[i].name.should == name
    end
  end
  
  it "parses select number" do
    col = parse_select_single_column '1'
    col.should be_a_kind_of NumberColumn
    col.value.should == 1
  end
  
  it "parses select number with minus" do
    col = parse_select_single_column '-1'
    col.should be_a_kind_of NumberColumn
    col.value.should == -1
  end
  
  it "parses select number with plus" do
    col = parse_select_single_column '+1'
    col.should be_a_kind_of NumberColumn
    col.value.should == 1
  end
  
  it "parses select parenthesized number" do
    col = parse_select_single_column '(1)'
    col.should be_a_kind_of NumberColumn
    col.value.should == 1
  end
  
  it "parses select string" do
    col = parse_select_single_column '"hello"'
    col.should be_a_kind_of StringColumn
    col.value.should == 'hello'
  end
  
  it "parses select false" do
    col = parse_select_single_column 'false'
    col.should be_a_kind_of BooleanColumn
    col.value.should == false
  end
  
  it "parses select true" do
    col = parse_select_single_column 'true'
    col.should be_a_kind_of BooleanColumn
    col.value.should == true
  end
  
  it "parses select date" do
    col = parse_select_single_column 'date "2010-01-02"' 
    col.should be_a_kind_of DateColumn
    col.value.should == Date.parse('2010-01-02')
  end
  
  it "parses select timeofday" do
    col = parse_select_single_column 'timeofday "12:01:02"' 
    col.should be_a_kind_of TimeOfDayColumn
    col.value.hour.should == 12
    col.value.min.should == 1
    col.value.sec.should == 2
  end
  
  it "parses select datetime" do
    col = parse_select_single_column 'datetime "2010-01-02 12:02:03"' 
    col.should be_a_kind_of DateTimeColumn
    col.value.should == Time.parse('2010-01-02 12:02:03')
  end
  
  [
    ['*', ScalarFunctionColumn::Product],
    ['/', ScalarFunctionColumn::Quotient],
    ['+', ScalarFunctionColumn::Sum],
    ['-', ScalarFunctionColumn::Difference]
  ].each do |str, func|
    it "parses select #{func}" do
      col = parse_select_single_column "1 #{str} one"
      col.should be_a_kind_of ScalarFunctionColumn
      col.function.should == func
      
      args = col.arguments 
      args.length.should == 2
      
      args[0].should be_a_kind_of NumberColumn
      args[0].value.should == 1
      
      args[1].should be_a_kind_of IdColumn
      args[1].name.should == "one"
    end
  end
  
  it "parses compound arithmetic" do
    col = parse_select_single_column "1 * 2 + 3 * 4"
    col.should be_kind_of ScalarFunctionColumn
    col.function.should == ScalarFunctionColumn::Sum
    
    col.arguments.length.should == 2
    
    [0, 1].each do |i|
      sub = col.arguments[i]
      sub.should be_kind_of ScalarFunctionColumn
      sub.function.should == ScalarFunctionColumn::Product
      sub.arguments.length.should == 2
    end
  end
  
  [
    ['min', AggregateColumn::Min],
    ['max', AggregateColumn::Max],
    ['count', AggregateColumn::Count],
    ['avg', AggregateColumn::Avg],
    ['sum', AggregateColumn::Sum]
  ].each do |str, function|
    it "parses #{str} aggregation" do
      col = parse_select_single_column "#{str}(col)" 
      col.should be_a_kind_of AggregateColumn
      col.function.should == function
      
      col.argument.should be_a_kind_of IdColumn
      col.argument.name.should == 'col'
    end
    
    it_parses_as_identifier str
  end
  
  [
    ['year', ScalarFunctionColumn::Year],
    ['month', ScalarFunctionColumn::Month],
    ['day', ScalarFunctionColumn::Day],
    ['hour', ScalarFunctionColumn::Hour],
    ['minute', ScalarFunctionColumn::Minute],
    ['second', ScalarFunctionColumn::Second],
    ['millisecond', ScalarFunctionColumn::Millisecond],
    ['now', ScalarFunctionColumn::Now],
    ['datediff', ScalarFunctionColumn::DateDiff],
    ['lower', ScalarFunctionColumn::Lower],
    ['upper', ScalarFunctionColumn::Upper],
    ['quarter', ScalarFunctionColumn::Quarter],
    ['dayofweek', ScalarFunctionColumn::DayOfWeek],
    ['todate', ScalarFunctionColumn::ToDate],
    ['concat', ScalarFunctionColumn::Concat],
  ].each do |str, function|
    it "parses #{str} function" do
      col = parse_select_single_column "#{str}(col)"
      col.should be_a_kind_of ScalarFunctionColumn
      col.function.should == function
      
      col.arguments.length.should == 1
      col.arguments[0].should be_a_kind_of IdColumn
      col.arguments[0].name.should == 'col'
    end
    
    it_parses_as_identifier str
  end
  
  it "parses datediff function with many arguments" do
    col = parse_select_single_column "datediff(1, 2)" 
    col.should be_a_kind_of ScalarFunctionColumn
    col.function.should == ScalarFunctionColumn::DateDiff
    
    col.arguments.length.should == 2
    col.arguments[0].value == 1
    col.arguments[1].value == 2
  end
  
  [
    ['=', BinaryExpression::Eq],
    ['!=', BinaryExpression::Neq],
    ['<>', BinaryExpression::Neq],
    ['<', BinaryExpression::Lt],
    ['<=', BinaryExpression::Lte],
    ['>', BinaryExpression::Gt],
    ['>=', BinaryExpression::Gte],
    ['contains', BinaryExpression::Contains],
    ['starts with', BinaryExpression::StartsWith],
    ['ends with', BinaryExpression::EndsWith],
    ['matches', BinaryExpression::Matches],
    ['like', BinaryExpression::Like]
  ].each do |str, operator|
    it "parses where #{str} 1" do
      exp = parse_where "col #{str} 1"
      exp.should be_a_kind_of BinaryExpression
      exp.operator.should == operator
      exp.left.should be_a_kind_of IdColumn
      exp.left.name.should == 'col'
      exp.right.should be_a_kind_of NumberColumn
      exp.right.value.should == 1
    end
  end
  
  it_parses_as_identifier 'contains'
  it_parses_as_identifier 'starts'
  it_parses_as_identifier 'ends'
  it_parses_as_identifier 'with'
  it_parses_as_identifier 'matches'
  it_parses_as_identifier 'like'
  it_parses_as_identifier 'no_values'
  it_parses_as_identifier 'no_format'
  it_parses_as_identifier 'is'
  it_parses_as_identifier 'null'
  
  it_parses_columns_container 'group by', :group_by
  it_parses_columns_container 'pivot', :pivot
  
  [
    ['', Sort::Asc],
    [' asc', Sort::Asc],
    [' desc', Sort::Desc]
  ].each do |str, order|
    it "parses order by" do
      query = parse "order by foo #{order}, bar #{order}"
      order_by = query.order_by
      
      sorts = order_by.sorts 
      
      sorts.length.should == 2
      
      sorts[0].column.should be_a_kind_of IdColumn
      sorts[0].column.name.should == 'foo'
      sorts[0].order.should == order
      
      sorts[1].column.should be_a_kind_of IdColumn
      sorts[1].column.name.should == 'bar'
      sorts[1].order.should == order
    end
  end
  
  it "parses limit" do
    query = parse "limit 10"
    query.limit.should == 10
  end
  
  it "parses offset" do
    query = parse "offset 10"
    query.offset.should == 10
  end
  
  it "parses label" do
    query = parse "label one 'unu', two 'du'"
    labels = query.labels
    labels.length.should == 2
    
    labels[0].column.should be_a_kind_of IdColumn
    labels[0].column.name.should == 'one'
    labels[0].label.should == 'unu'
    
    labels[1].column.should be_a_kind_of IdColumn
    labels[1].column.name.should == 'two'
    labels[1].label.should == 'du'
  end
  
  it "parses format" do
    query = parse "format one 'unu', two 'du'"
    formats = query.formats
    formats.length.should == 2
    
    formats[0].column.should be_a_kind_of IdColumn
    formats[0].column.name.should == 'one'
    formats[0].pattern.should == 'unu'
    
    formats[1].column.should be_a_kind_of IdColumn
    formats[1].column.name.should == 'two'
    formats[1].pattern.should == 'du'
  end
  
  it "parses options" do
    query = parse "options no_values no_format"
    options = query.options
    options.no_values.should be_true
    options.no_format.should be_true
  end
  
  [
    ['and', LogicalExpression::And],
    ['or', LogicalExpression::Or]
  ].each do |str, op|
    it "parses where with two #{str}" do
      query = parse "where 1 = 1 #{str} 1 = 2 #{str} 1 = 3"
      exp = query.where.expression 
      
      exp.should be_a_kind_of LogicalExpression
      exp.operator.should == op
      exp.operands.length.should == 3
    end
  end
  
  ['+', '-', '*', '/'].each do |op|
    it "parses where with two #{op}" do
      parse "where 1 #{op} 2 #{op} 3 = 4"
    end
  end
  
  it_raises_on 'select'
  it_raises_on 'where'
  it_raises_on 'where 1'
  it_raises_on 'where 1 <'
  it_raises_on 'group by'
  it_raises_on 'group by foo bar'
  it_raises_on 'pivot'
  it_raises_on 'order by'
  it_raises_on 'order by foo bar'
  it_raises_on 'limit'
  it_raises_on 'limit foo'
  it_raises_on 'offset'
  it_raises_on 'offset foo'
  it_raises_on 'label'
  it_raises_on 'label foo'
  it_raises_on 'label `foo`'
  it_raises_on 'format'
  it_raises_on 'format foo'
  it_raises_on 'format `foo`'
  it_raises_on 'options'
  it_raises_on 'options foobar'
end
