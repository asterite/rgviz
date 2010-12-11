module Rgviz
  class Visitor
    ['query', 'select', 'group_by', 'pivot', 'order_by',
     'sort', 'where', 'label', 'format',
     'logical_expression', 'binary_expression', 'unary_expression',
     'id_column', 'number_column', 'string_column',
     'boolean_column', 'date_column', 'date_time_column',
     'time_of_day_column', 'scalar_function_column', 'aggregate_column'].each do |name|
      define_method "visit_#{name}" do |node|
        true
      end
      
      define_method "end_visit_#{name}" do |node|
        true
      end
    end
  end
end
