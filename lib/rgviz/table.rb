module Rgviz
  class Table
    attr_accessor :cols
    attr_accessor :rows
    
    def initialize
      @cols = []
      @rows = []
    end
  end
  
  class Column
    attr_accessor :id
    attr_accessor :label
    attr_accessor :type
    attr_accessor :pattern
    attr_accessor :p
    
    def initialize(attributes = {})
      attributes.each do |key, value|
        self.send "#{key}=", value
      end
    end
  end
  
  class Row
    attr_accessor :c
    
    def initialize
      @c = []
    end
  end
  
  class Cell
    attr_accessor :v
    attr_accessor :f
    attr_accessor :p
    
    def initialize(attributes = {})
      attributes.each do |key, value|
        self.send "#{key}=", value
      end
    end
  end
end
