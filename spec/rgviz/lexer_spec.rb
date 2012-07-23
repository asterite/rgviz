require 'rgviz'

include Rgviz

describe Lexer do
  def self.it_lexes_keyword(str, token_value)
    it "lexes #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == token_value
    end
    
    it "lexes #{str} upcase" do
      lex = Lexer.new str.upcase
      tok = lex.next_token
      tok.value.should == token_value
    end
  end
  
  def self.it_lexes_id(str, id = str)
    it "lexes identifier #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == Token::ID
      tok.string.should == id
    end
  end
  
  def self.it_lexes_string(str, id = str)
    it "lexes string #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == Token::STRING
      tok.string.should == id
    end
  end
  
  def self.it_lexes_token(str, token_value)
    it "lexes #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == token_value
    end
  end
  
  def self.it_lexes_integer(str, number)
    it "lexes #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == Token::INTEGER
      tok.number.should == number
    end
  end
  
  def self.it_lexes_decimal(str, number)
    it "lexes #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == Token::DECIMAL
      tok.number.should == number
    end
  end
  
  def self.it_lexes_eof(str)
    it "lexes eof #{str}" do
      lex = Lexer.new str
      tok = lex.next_token
      tok.value.should == Token::EOF
    end
  end
  
  def self.it_lexes_error(str)
    it "lexes error #{str}" do
      lex = Lexer.new "x#{str}"
      tok = lex.next_token
      tok.value.should == Token::ID
      tok.string.should == 'x'
      lambda { lex.next_token }.should raise_error(ParseException)
    end
  end
  
  it_lexes_keyword 'and', Token::And
  it_lexes_keyword 'asc', Token::Asc
  it_lexes_keyword 'avg', Token::Avg
  it_lexes_keyword 'by', Token::By
  it_lexes_keyword 'contains', Token::Contains
  it_lexes_keyword 'count', Token::Count
  it_lexes_keyword 'date', Token::Date
  it_lexes_keyword 'datediff', Token::DateDiff
  it_lexes_keyword 'datetime', Token::DateTime
  it_lexes_keyword 'day', Token::Day
  it_lexes_keyword 'dayofweek', Token::DayOfWeek
  it_lexes_keyword 'desc', Token::Desc
  it_lexes_keyword 'ends', Token::Ends
  it_lexes_keyword 'false', Token::False
  it_lexes_keyword 'format', Token::Format
  it_lexes_keyword 'group', Token::Group
  it_lexes_keyword 'hour', Token::Hour
  it_lexes_keyword 'is', Token::Is
  it_lexes_keyword 'label', Token::Label
  it_lexes_keyword 'like', Token::Like
  it_lexes_keyword 'limit', Token::Limit
  it_lexes_keyword 'lower', Token::Lower
  it_lexes_keyword 'matches', Token::Matches
  it_lexes_keyword 'millisecond', Token::Millisecond
  it_lexes_keyword 'min', Token::Min
  it_lexes_keyword 'minute', Token::Minute
  it_lexes_keyword 'max', Token::Max
  it_lexes_keyword 'month', Token::Month
  it_lexes_keyword 'not', Token::Not
  it_lexes_keyword 'now', Token::Now
  it_lexes_keyword 'no_format', Token::NoFormat
  it_lexes_keyword 'no_values', Token::NoValues
  it_lexes_keyword 'null', Token::Null
  it_lexes_keyword 'offset', Token::Offset
  it_lexes_keyword 'options', Token::Options
  it_lexes_keyword 'or', Token::Or
  it_lexes_keyword 'order', Token::Order
  it_lexes_keyword 'pivot', Token::Pivot
  it_lexes_keyword 'quarter', Token::Quarter
  it_lexes_keyword 'second', Token::Second
  it_lexes_keyword 'select', Token::Select
  it_lexes_keyword 'starts', Token::Starts
  it_lexes_keyword 'sum', Token::Sum
  it_lexes_keyword 'timeofday', Token::TimeOfDay
  it_lexes_keyword 'timestamp', Token::Timestamp
  it_lexes_keyword 'todate', Token::ToDate
  it_lexes_keyword 'true', Token::True
  it_lexes_keyword 'upper', Token::Upper
  it_lexes_keyword 'where', Token::Where
  it_lexes_keyword 'with', Token::With
  it_lexes_keyword 'year', Token::Year
  
  it_lexes_id 'selected'
  it_lexes_id '  selected  ', 'selected'
  it_lexes_id '`selected`', 'selected'
  it_lexes_id '`some string`', 'some string'
  it_lexes_id 'hello123bye'
  it_lexes_id 'hello_123_bye'
  it_lexes_string "'hello world'", "hello world"
  it_lexes_string '"hello world"', "hello world"
  
  it_lexes_token '+', Token::PLUS
  it_lexes_token '-', Token::MINUS
  it_lexes_token '*', Token::STAR
  it_lexes_token '/', Token::SLASH
  
  it_lexes_token ',', Token::COMMA
  it_lexes_token '(', Token::LPAREN
  it_lexes_token ')', Token::RPAREN
  it_lexes_token '=', Token::EQ
  it_lexes_token '<', Token::LT
  it_lexes_token '<=', Token::LTE
  it_lexes_token '>', Token::GT
  it_lexes_token '>=', Token::GTE
  it_lexes_token '!=', Token::NEQ
  it_lexes_token '<>', Token::NEQ
  
  it_lexes_integer '1', 1
  it_lexes_integer '0123', 123
  it_lexes_integer '45678791230', 45678791230
  it_lexes_decimal '123.456', 123.456
  it_lexes_decimal '.456', 0.456
  
  it_lexes_eof ''
  it_lexes_eof "   \t\n\r"
  
  it_lexes_error '!'
  it_lexes_error '?'
  it_lexes_error ':'
  
  it_lexes_keyword 'concat', Token::Concat
end
