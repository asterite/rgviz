require 'rgviz'

include Rgviz

describe MemoryExecutor do

  Types = [[:id, :number], [:name, :string], [:age, :number], [:birthday, :date]]

  def exec(query, rows)
    exec = MemoryExecutor.new rows, Types
    exec.execute query
  end

  def format_datetime(date)
    date.strftime "%Y-%m-%d %H:%M:%S"
  end

  def format_date(date)
    date.strftime "%Y-%m-%d"
  end

  def self.it_processes_single_select_column(query, id, type, value, label, test_options = {})
    it "processes select #{query}", test_options do
      if block_given?
        rows = yield
      else
        rows = [[1, 'Foo', 20, Date.today]]
      end

      table = exec "select #{query}", rows
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
    expected_rows = [[1, 'Foo', 20, format_date(rows.first[3])]]

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
    expected_rows.first.each do |val|
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
  it_processes_single_select_column "concat('foo', 'bar')", 'c0', :string, 'foobar', "concat('foo', 'bar')"
  it_processes_single_select_column "datediff(date '2010-10-12', date '2010-10-01')", 'c0', :number, 11, "dateDiff(date '2010-10-12', date '2010-10-01')"
  it_processes_single_select_column "year(datetime '2010-01-02 10:11:12')", 'c0', :number, 2010, "year(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "month(datetime '2010-01-02 10:11:12')", 'c0', :number, 1, "month(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "day(datetime '2010-01-02 10:11:12')", 'c0', :number, 2, "day(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "dayofweek(date '2010-10-12')", 'c0', :number, 2, "dayOfWeek(date '2010-10-12')"
  it_processes_single_select_column "hour(datetime '2010-01-02 10:11:12')", 'c0', :number, 10, "hour(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "minute(datetime '2010-01-02 10:11:12')", 'c0', :number, 11, "minute(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "second(datetime '2010-01-02 10:11:12')", 'c0', :number, 12, "second(datetime '2010-01-02 10:11:12')"
  it_processes_single_select_column "quarter(datetime '2010-04-02 10:11:12')", 'c0', :number, 2, "quarter(datetime '2010-04-02 10:11:12')"
  it_processes_single_select_column "round(1.2)", 'c0', :number, 1, "round(1.2)", :extensions => true
  it_processes_single_select_column "round(1.9)", 'c0', :number, 2, "round(1.9)", :extensions => true
  it_processes_single_select_column "floor(1.2)", 'c0', :number, 1, "floor(1.2)", :extensions => true
  it_processes_single_select_column "floor(1.9)", 'c0', :number, 1, "floor(1.9)", :extensions => true
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

  it "processes group by with where" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'two', 4, Date.today],
    ]

    table = exec "select max(age) where name != 'one' group by name order by name desc", rows

    table.rows.length.should == 1
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 4
  end

  it "processes group by with scalar" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'ONE', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'TWO', 4, Date.today],
    ]

    table = exec 'select max(age) group by lower(name) order by lower(name)', rows

    table.rows.length.should == 2
    table.rows[0].c.length.should == 1
    table.rows[0].c[0].v.should == 2
    table.rows[1].c.length.should == 1
    table.rows[1].c[0].v.should == 4
  end

  it "processes group by selecting group column" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'two', 4, Date.today],
    ]

    table = exec 'select name, max(age) group by name order by name', rows

    table.rows.length.should == 2
    table.rows[0].c.length.should == 2
    table.rows[0].c[0].v.should == 'one'
    table.rows[0].c[1].v.should == 2
    table.rows[1].c.length.should == 2
    table.rows[1].c[0].v.should == 'two'
    table.rows[1].c[1].v.should == 4
  end

  it "processes group by selecting scalar over group column" do
    rows = [
      [1, 'one', 1, Date.today],
      [1, 'one', 2, Date.today],
      [1, 'two', 3, Date.today],
      [1, 'two', 4, Date.today],
    ]

    table = exec 'select upper(name), max(age) group by name order by name', rows

    table.rows.length.should == 2
    table.rows[0].c.length.should == 2
    table.rows[0].c[0].v.should == 'ONE'
    table.rows[0].c[1].v.should == 2
    table.rows[1].c.length.should == 2
    table.rows[1].c[0].v.should == 'TWO'
    table.rows[1].c[1].v.should == 4
  end

  it_processes_single_select_column 'age where age > 3 order by age limit 1', 'age', :number, 4, 'age' do
    [1, 2, 3, 4, 5].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column 'age order by age limit 1 offset 2', 'age', :number, 2, 'age' do
    [1, 2, 3, 4, 5].map{|i| [1, 'Foo', i, Date.today]}
  end

  it_processes_single_select_column "1 + 2 label 1 + 2 'my name'", 'c0', :number, 3, "my name"

  it "processes pivot without group by" do
    rows = [
      [1, 'Eng', 1000, Date.parse('2000-01-12')],
      [2, 'Eng', 500, Date.parse('2000-01-12')],
      [3, 'Eng', 600, Date.parse('2000-01-13')],
      [4, 'Sales', 400, Date.parse('2000-01-12')],
      [5, 'Sales', 350, Date.parse('2000-01-12')],
      [6, 'Marketing', 800, Date.parse('2000-01-13')]
    ]

    table = exec 'select sum(age) pivot name order by name', rows

    table.cols.length.should == 3

    i = 0
    [['c0', :number, 'Eng sum(age)'],
     ['c1', :number, 'Marketing sum(age)'],
     ['c2', :number, 'Sales sum(age)']].each do |id, type, label|
      table.cols[i].id.should == id
      table.cols[i].type.should == type
      table.cols[i].label.should == label
      i += 1
    end

    table.rows.length.should == 1

    i = 0
    [[2100, 800, 750]].each do |values|
      table.rows[i].c.length.should == 3
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "processes pivot" do
    rows = [
      [1, 'Eng', 1000, Date.parse('2000-01-12')],
      [2, 'Eng', 500, Date.parse('2000-01-12')],
      [3, 'Eng', 600, Date.parse('2000-01-13')],
      [4, 'Sales', 400, Date.parse('2000-01-12')],
      [5, 'Sales', 350, Date.parse('2000-01-12')],
      [6, 'Marketing', 800, Date.parse('2000-01-13')]
    ]

    table = exec 'select name, sum(age) group by name pivot birthday order by name', rows

    table.cols.length.should == 3

    i = 0
    [['c0', :string, 'name'],
     ['c1', :number, '2000-01-12 sum(age)'],
     ['c2', :number, '2000-01-13 sum(age)']].each do |id, type, label|
      table.cols[i].id.should == id
      table.cols[i].type.should == type
      table.cols[i].label.should == label
      i += 1
    end

    table.rows.length.should == 3

    i = 0
    [['Eng', 1500, 600],
     ['Marketing', nil, 800],
     ['Sales', 750, nil]].each do |values|
      table.rows[i].c.length.should == 3
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "processes pivot2" do
    rows = [
      [1, 'Eng', 1000, Date.parse('2000-01-12')],
      [2, 'Eng', 500, Date.parse('2000-01-12')],
      [3, 'Eng', 600, Date.parse('2000-01-13')],
      [4, 'Sales', 400, Date.parse('2000-01-12')],
      [5, 'Sales', 350, Date.parse('2000-01-12')],
      [6, 'Marketing', 800, Date.parse('2000-01-13')]
    ]

    table = exec 'select sum(age), name group by name pivot birthday order by name', rows

    table.cols.length.should == 3

    i = 0
    [['c0', :number, '2000-01-12 sum(age)'],
     ['c1', :number, '2000-01-13 sum(age)'],
     ['c2', :string, 'name']].each do |id, type, label|
      table.cols[i].id.should == id
      table.cols[i].type.should == type
      table.cols[i].label.should == label
      i += 1
    end

    table.rows.length.should == 3

    i = 0
    [[1500, 600, 'Eng'],
     [nil, 800, 'Marketing'],
     [750, nil, 'Sales']].each do |values|
      table.rows[i].c.length.should == 3
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "processes pivot3" do
    rows = [
      [1, 'Eng', 10, Date.parse('2000-01-12')],
      [2, 'Eng', 10, Date.parse('2001-02-12')]
    ]

    table = exec 'select name, sum(age) group by name pivot year(birthday), month(birthday)', rows

    table.cols.length.should == 3

    i = 0
    [['Eng', 10, 10]].each do |values|
      table.rows[i].c.length.should == 3
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "processes pivot4" do
    rows = [
      [1, 'Eng', 10, Date.parse('2000-01-12')],
      [2, 'Sales', 20, Date.parse('2001-02-12')]
    ]

    table = exec 'select birthday, month(birthday), sum(age) group by month(birthday) pivot name order by name', rows

    table.cols.length.should == 5

    i = 0
    [
      ['2000-01-12', nil, 1, 10, nil],
      [nil, '2001-02-12', 2, nil, 20],
    ].each do |values|
      table.rows[i].c.length.should == 5
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "processes pivot with no results" do
    rows = [
      [1, 'Eng', 10, Date.parse('2000-01-12')],
      [2, 'Sales', 20, Date.parse('2001-02-12')]
    ]

    table = exec 'select birthday, sum(age) where 1 = 2 group by month(birthday) pivot name order by name', rows

    table.cols.length.should == 2

    i = 0
    [['birthday', :date, 'birthday'],
     ['c1', :number, 'sum(age)']].each do |id, type, label|
      table.cols[i].id.should == id
      table.cols[i].type.should == type
      table.cols[i].label.should == label
      i += 1
    end
  end

  it "processes pivot with group by not in select" do
    rows = [
      [1, 'Eng', 10, Date.parse('2000-01-12')],
      [2, 'Sales', 20, Date.parse('2001-02-12')]
    ]

    table = exec 'select birthday, sum(age) group by month(birthday) pivot name order by name', rows

    table.cols.length.should == 4

    i = 0
    [
      ['2000-01-12', nil, 10, nil],
      [nil, '2001-02-12', nil, 20],
    ].each do |values|
      table.rows[i].c.length.should == 4
      values.each_with_index do |v, j|
        table.rows[i].c[j].v.should == v
      end
      i += 1
    end
  end

  it "accepts options" do
    exec = MemoryExecutor.new [], Types
    exec.execute "select *", {}
  end
end
