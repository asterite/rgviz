module Rgviz
  module HtmlRenderer
    def self.render(table)
      string = "<html>\n"
      string << "<body>\n"
      string << "<table border=\"1\" cellpadding=\"2\" cellspacing=\"0\">\n"
      
      string << "<tr style=\"font-weight: bold; background-color: #aaa;\">\n"
      table.cols.each do |row|
        string << "<td>#{row.label}</td>\n"
      end
      string << "<tr>\n"
      
      table.rows.each_with_index do |row, i|
        color = i % 2 == 0 ? '#f0f0f0' : '#ffffff'
        string << "<tr style=\"background-color: #{color}\">\n"
        row.c.each do |col|
          string << "<td>#{col.f || col.v}</td>\n"
        end
        string << "<tr>\n"
      end
      
      string << "</table>\n"
      string << "</body>\n"
      string << "</html>\n"   
      string
    end
  end
end
