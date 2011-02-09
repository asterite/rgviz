require 'rgviz'

include Rgviz

describe MemoryExecutor do

  Types = [[:id, :number], [:name, :string], [:age, :number], [:birthday, :date]]

  def exec(query, rows, options = {})
    exec = MemoryExecutor.new query, rows, Types
    exec.execute options
  end

  def format_datetime(date)
    date.strftime "%Y-%m-%d %H:%M:%S"
  end

  def format_date(date)
    date.strftime "%Y-%m-%d"
  end

  def self.it_processes_single_select_column(query, id, type, value, label, options = {})
    it "processes select #{query}" do
      if block_given?
        rows = yield
      else
        rows = [[1, 'Foo', 20, Date.today]]
      end

      table = exec "select #{query}", rows, options
      table.cols.length.should == 1

      table.cols[0].id.should == id
      table.cols[0].type.should == type
      table.cols[0].label.should == label

      table.rows.length.should == 1
      table.rows[0].c.length.should == 1

      table.rows[0].c[0].v.should == value
    end
  end

  it "processes select *" do
    rows = [[1, 'Foo', 20, Date.today]]

    table = exec 'select *', rows
    table.cols.length.should == 4

    i = 0
    Types.each do |id, type|
      table.cols[i].id.should == id
      table.cols[i].type.should == type
      table.cols[i].label.should == id
      i += 1
    end

    table.rows.length.should == 1
    table.rows[0].c.length.should == 4

    i = 0
    rows.first.each do |val|
      table.rows[0].c[i].v.should == val
      i += 1
    end
  end

  it_processes_single_select_column 'name', 'name', :string, 'Foo', 'name' do
    [[1, 'Foo', 20, Date.today]]
  end

  it_processes_single_select_column '1', 'c0', :number, 1, '1'
  it_processes_single_select_column '1.2', 'c0', :number, 1.2, '1.2'
  it_processes_single_select_column '"hello"', 'c0', :string, 'hello', "'hello'"
  it_processes_single_select_column 'false', 'c0', :boolean, false, 'false'
  it_processes_single_select_column 'true', 'c0', :boolean, true, 'true'
  it_processes_single_select_column 'date "2010-01-02"', 'c0', :date, '2010-01-02', "date '2010-01-02'"
  it_processes_single_select_column 'datetime "2010-01-02 10:11:12"', 'c0', :datetime, '2010-01-02 10:11:12', "datetime '2010-01-02 10:11:12'"
  it_processes_single_select_column 'timeofday "10:11:12"', 'c0', :timeofday, '10:11:12', "timeofday '10:11:12'"
  it_processes_single_select_column '1 + 2', 'c0', :number, 3, '1 + 2'
  it_processes_single_select_column '3 - 2', 'c0', :number, 1, '3 - 2'
  it_processes_single_select_column '2 * 3', 'c0', :number, 6, '2 * 3'
  it_processes_single_select_column '6 / 3', 'c0', :number, 2, '6 / 3'
  it_processes_single_select_column '3 * age', 'c0', :number, 60, '3 * age' do
    [[1, 'Foo', 20, Date.today]]
  end
  it_processes_single_select_column "concat('foo', 'bar')", 'c0', :string, 'foobar', "concat('foo', 'bar')", :extensions => true
  it_processes_single_select_column "datediff(date '2010-10-12', date '2010-10-01')", 'c0', :number, 11, "dateDiff(date '2010-10-12', date '2010-10-01')"
  it_processes_single_select_column "year(datetime '2010-01-02 10:11:12')", 'c0', :number, 2010, "year(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "month(datetime '2010-01-02 10:11:12')", 'c0', :number, 1, "month(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "day(datetime '2010-01-02 10:11:12')", 'c0', :number, 2, "day(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "dayofweek(date '2010-10-12')", 'c0', :number, 2, "dayOfWeek(date '2010-10-12')"
  it_processes_single_select_column "hour(datetime '2010-01-02 10:11:12')", 'c0', :number, 10, "hour(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "minute(datetime '2010-01-02 10:11:12')", 'c0', :number, 11, "minute(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "second(datetime '2010-01-02 10:11:12')", 'c0', :number, 12, "second(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "quarter(datetime '2010-04-02 10:11:12')", 'c0', :number, 2, "quarter(datetime '2010-04-02 10:11:12')"
  it_processes_single_select_column "lower('FOO')", 'c0', :string, 'foo', "lower('FOO')"
  it_processes_single_select_column "upper('foo')", 'c0', :string, 'FOO', "upper('foo')"
  it_processes_single_select_column "toDate(date '2010-10-12')", 'c0', :date, '2010-10-12', "toDate(date '2010-10-12')"
  it_processes_single_select_column "toDate(datetime '2010-10-12 10:11:12')", 'c0', :date, '2010-10-12', "toDate(datetime '2010-10-12 10:11:12')"
  it_processes_single_select_column "toDate(1234567890000)", 'c0', :date, '2009-02-13', "toDate(1234567890000)"

  it_processes_single_select_column 'sum(age)', 'c0', :number, 6, 'sum(age)' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'avg(age)', 'c0', :number, 30, 'avg(age)' do
    [10, 20, 60].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'count(age)', 'c0', :number, 3, 'count(age)' do
    3.times.map{|i| [1, 'Foo', 20, Date.today]}
  end

  it_processes_single_select_column 'max(age)', 'c0', :number, 3, 'max(age)' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'min(age)', 'c0', :number, 1, 'min(age)' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age > 2', 'age', :number, 3, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age >= 3', 'age', :number, 3, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age < 2', 'age', :number, 1, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age <= 1', 'age', :number, 1, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age = 2', 'age', :number, 2, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age != 1', 'age', :number, 2, 'age' do
    [1, 2].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column "name where name contains 'foo'", 'name', :string, 'one foo two', 'name' do
    [[1, 'one foo two', 20, Date.today], [1, 'one bar two', 20, Date.today]]
  end

  it_processes_single_select_column "name where name starts with 'foo'", 'name', :string, 'foo one two', 'name' do
    [[1, 'foo one two', 20, Date.today], [1, 'bar one two', 20, Date.today]]
  end

  it_processes_single_select_column "name where name ends with 'foo'", 'name', :string, 'one two foo', 'name' do
    [[1, 'one two foo', 20, Date.today], [1, 'one two bar', 20, Date.today]]
  end

  it_processes_single_select_column "name where name matches 'one two .*'", 'name', :string, 'one two foo baz', 'name' do
    [[1, 'one two foo baz', 20, Date.today], [1, 'bar one two', 20, Date.today]]
  end

  it_processes_single_select_column 'age where age > 2 and age <= 3', 'age', :number, 3, 'age' do
    [1, 2, 3, 4, 5].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where age <= 1 or age < 1', 'age', :number, 1, 'age' do
    [1, 2, 3, 4, 5].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age where not age <= 2', 'age', :number, 3, 'age' do
    [1, 2, 3].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'id where age is null', 'id', :number, 3, 'id' do
    j = 0
    [1, 2, nil].map{|i| j += 1; [j, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'id where age is not null', 'id', :number, 2, 'id' do
    j = 0
    [nil, 2, nil].map{|i| j += 1; [j, 'Foo', i, Date.today]}
  end

  it "processes order by" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
    ]

    table = exec 'select age order by age', rows

    table.rows.length.should == 3
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 1
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 2
    table.rows[2].c.length.should == 1
    table.rows[2].c[0].v.should == 3
  end

  it "processes order by desc" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
    ]

    table = exec 'select age order by age desc', rows

    table.rows.length.should == 3
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 3
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 2
    table.rows[2].c.length.should == 1
    table.rows[2].c[0].v.should == 1
  end

  it "processes order by many columns" do
    rows = [
      [2, 'one', 1, Date.today],
      [1, 'one', 1, Date.today],
      [0, 'two', 2, Date.today],
    ]

    table = exec 'select id order by age, id', rows

    table.rows.length.should == 3
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 1
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 2
    table.rows[2].c.length.should == 1
    table.rows[2].c[0].v.should == 0
  end

  it "processes group by" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'two', 4, Date.today],
    ]

    table = exec 'select max(age) group by name order by name', rows

    table.rows.length.should == 2
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 2
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 4
  end

  it "processes group by order desc" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'two', 4, Date.today],
    ]

    table = exec 'select max(age) group by name order by name desc', rows

    table.rows.length.should == 2
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 4
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 2
  end
end
