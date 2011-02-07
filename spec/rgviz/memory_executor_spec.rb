require 'rgviz'

include Rgviz

describe MemoryExecutor do

  Types = [[:id, :number], [:name, :string], [:age, :number], [:birthday, :date]]

  def exec(query, rows)
    exec = MemoryExecutor.new query, rows, Types
    exec.execute
  end

  def format_datetime(date)
    date.strftime "%y-%m-%d %h:%m:%s"
  end

  def format_date(date)
    date.strftime "%y-%m-%d"
  end

  def self.it_processes_single_select_column(query, id, type, value, label, options = {})
    it "processes select #{query}" do
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
end
