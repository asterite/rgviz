module Rgviz
  module CsvRenderer
    def self.render(table)
      string = ''
      table.cols.each_with_index do |row, i|
        string << ',' if i > 0
        string << CsvRenderer.format(row.label)
      end

      length = table.rows.length
      string << "\n" if length > 0

      table.rows.each_with_index do |row, i|
        row.c.each_with_index do |col, i|
          string << ',' if i > 0
          string << CsvRenderer.format((col.f || col.v).to_s)
        end
        string << "\n" if i != length - 1
      end
      string
    end

    def self.format(value)
      value = value.to_s.gsub('"', '""')

      return "\"#{value}\"" if value.start_with?(' ') || value.end_with?(' ')

      len = value.length
      value.chars.each do |c|
        return "\"#{value}\"" if c == ',' || c == "\n" || c == "\r" || c == "\t"
      end

      value
    end
  end
end
