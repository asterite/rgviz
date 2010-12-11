require 'strscan'

module Rgviz
  class Lexer < StringScanner
    def initialize(str, options = {})
      super
      @token = Token.new
      @extensions = options[:extensions]
    end
    
    def next_token
      @token.start = pos
      @token.string = nil
      @token.value = nil
      
      skip /\s*/
      
      if eos?
        @token.value = Token::EOF
      elsif scan /"([^"]*)"/
        @token.value = Token::STRING
        @token.string = self[1]
      elsif scan /'([^']*)'/
        @token.value = Token::STRING
        @token.string = self[1]
      elsif scan /`([^`]*)`/
        @token.value = Token::ID
        @token.string = self[1]
      elsif scan /\d+\.\d*/ or scan /\.\d+/
        @token.value = Token::DECIMAL
        @token.number = matched.to_f
      elsif scan /\d+/
        @token.value = Token::INTEGER
        @token.number = matched.to_f
      else
        @token.value = if scan /\+/ then Token::PLUS
          elsif scan /\-/ then Token::MINUS 
          elsif scan /\*/ then Token::STAR
          elsif scan /\// then Token::SLASH
          elsif scan /\,/ then Token::COMMA
          elsif scan /\(/ then Token::LPAREN
          elsif scan /\)/ then Token::RPAREN
          elsif scan /\=/ then Token::EQ
          elsif scan /\!\=/ or scan /\<\>/ then Token::NEQ
          elsif scan /\>\=/ then Token::GTE
          elsif scan /\>/ then Token::GT          
          elsif scan /\<\=/ then Token::LTE
          elsif scan /\</ then Token::LT
          elsif scan /and\b/i then Token::And
          elsif scan /asc\b/i then Token::Asc
          elsif scan /avg\b/i then Token::Avg
          elsif scan /by\b/i then Token::By
          elsif @extensions and scan /concat\b/i then Token::Concat
          elsif scan /contains\b/i then Token::Contains
          elsif scan /count\b/i then Token::Count
          elsif scan /date\b/i then Token::Date
          elsif scan /datediff\b/i then Token::DateDiff
          elsif scan /datetime\b/i then Token::DateTime        
          elsif scan /day\b/i then Token::Day
          elsif scan /dayofweek\b/i then Token::DayOfWeek        
          elsif scan /desc\b/i then Token::Desc
          elsif scan /ends\b/i then Token::Ends
          elsif scan /false\b/i then Token::False
          elsif scan /format\b/i then Token::Format
          elsif scan /group\b/i then Token::Group
          elsif scan /hour\b/i then Token::Hour
          elsif scan /is\b/i then Token::Is
          elsif scan /label\b/i then Token::Label
          elsif scan /like\b/i then Token::Like
          elsif scan /limit\b/i then Token::Limit
          elsif scan /lower\b/i then Token::Lower
          elsif scan /matches\b/i then Token::Matches
          elsif scan /max\b/i then Token::Max
          elsif scan /millisecond\b/i then Token::Millisecond
          elsif scan /min\b/i then Token::Min
          elsif scan /minute\b/i then Token::Minute
          elsif scan /month\b/i then Token::Month
          elsif scan /not\b/i then Token::Not
          elsif scan /now\b/i then Token::Now
          elsif scan /no_format\b/i then Token::NoFormat
          elsif scan /no_values\b/i then Token::NoValues
          elsif scan /null\b/i then Token::Null
          elsif scan /offset\b/i then Token::Offset
          elsif scan /options\b/i then Token::Options
          elsif scan /or\b/i then Token::Or
          elsif scan /order\b/i then Token::Order
          elsif scan /pivot\b/i then Token::Pivot
          elsif scan /quarter\b/i then Token::Quarter
          elsif scan /second\b/i then Token::Second
          elsif scan /select\b/i then Token::Select
          elsif scan /starts\b/i then Token::Starts
          elsif scan /sum\b/i then Token::Sum
          elsif scan /timeofday\b/i then Token::TimeOfDay
          elsif scan /timestamp\b/i then Token::Timestamp
          elsif scan /todate\b/i then Token::ToDate
          elsif scan /true\b/i then Token::True
          elsif scan /upper\b/i then Token::Upper
          elsif scan /where\b/i then Token::Where
          elsif scan /with\b/i then Token::With
          elsif scan /year\b/i then Token::Year
          elsif scan /[a-zA-Z_]\w*\b/ then Token::ID
        end
        
        if @token.value
          @token.string = matched
        else
          raise ParseException.new("Unexpected character #{string[pos].chr}")
        end
      end
      
      return @token
    end
  end
end
