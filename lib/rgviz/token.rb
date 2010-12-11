module Rgviz
  class Token

    And = :and
    Asc = :asc
    Avg = :avg
    By = :by
    Concat = :concat
    Contains = :contains
    Count = :count
    Desc = :desc
    Date = :date
    DateDiff = :dateDiff
    DateTime = :datetime
    Day = :day
    DayOfWeek = :dayOfWeek
    Ends = :ends
    False = :false
    Format = :format
    Group = :group
    Hour = :hour
    Is = :is
    Label = :label
    Like = :like
    Limit = :limit
    Lower = :lower
    Matches = :matches
    Millisecond = :millisecond
    Min = :min
    Minute = :minute
    Max = :max
    Month = :month
    Not = :not
    Now = :now
    NoFormat = :no_format
    NoValues = :no_values
    Null = :null
    Offset = :offset
    Options = :options
    Or = :or
    Order = :order
    Pivot = :pivot
    Quarter = :quarter
    Second = :second
    Select = :select
    Starts = :starts
    Sum = :sum
    TimeOfDay = :timeOfDay
    Timestamp = :timestamp
    ToDate = :toDate
    True = :true
    Upper = :upper
    Where = :where
    With = :with
    Year = :year
    
    ID = :ID
    INTEGER = :INTEGER
    DECIMAL = :DECIMAL
    STRING = :STRING
    
    PLUS = :'+'
    MINUS = :'-'
    STAR = :'*'
    SLASH = :'/'
    
    COMMA = :','
    LPAREN = :'('
    RPAREN = :')'
    EQ = :'='
    LT = :'<'
    LTE = :'<='
    GT = :'>'
    GTE = :'>='
    NEQ = :'!='
    
    EOF = :'<EOF>'
    
    attr_accessor :start
    attr_accessor :value
    attr_accessor :string
    attr_accessor :number
  end
end
