Rgviz
=====

[![Build Status](https://secure.travis-ci.org/asterite/rgviz.png?branch=master)](http://travis-ci.org/asterite/rgviz)

This library implements the [query language](http://code.google.com/apis/visualization/documentation/querylanguage.html) for the [Google Visualization API](http://code.google.com/apis/visualization/documentation/dev/implementing_data_source.html) wire protocol.

It can generate an AST of the query from a string. The AST nodes implement the [Visitor Pattern](http://en.wikipedia.org/wiki/Visitor_pattern) so you can easily work with it.

Installation
------------

    gem install rgviz

Ruby on Rails
-------------

There is a separate project on top of this library called [rgviz-rails](https://github.com/asterite/rgviz-rails), check it out!

Usage
-----

First you must require the library:

    require 'rubygems'
    require 'rgviz'

To parse a query:

    query = Rgviz::Parser.parse 'select name where age > 20'

More documentation
------------------

Read the [source code for the AST nodes](https://github.com/asterite/rgviz/blob/master/lib/rgviz/nodes.rb), it's not very big and the nodes just map to the query structure.

Extensions
----------

Rgviz supports the following extra functions:

* *concat*: converts each of its arguments to a string and then concatenates them. For example: <tt>concat(1, '-', '2')</tt> returns <tt>'1-2'</tt>. Can also receive just a single argument to convert it to a string.

These new functions are not part of Google's query language, but they are very handy so we added them. These functions are also supported by [rgviz-rails](https://github.com/asterite/rgviz-rails).

Using the Visitor Pattern
-------------------------

    class MyVisitor < Rgviz::Visitor
      def visit_select(node)
        # do something with the node
        puts 'before select'
        puts node.columns.length

        # returning true means visiting this node children
        true
      end

      def end_visit_select(node)
        # This will be invoked after visiting the node
        puts "after select"
      end

      def visit_id_column(node)
        puts node.name
      end
    end

    query = Rgviz::Parser.parse 'select name, age'
    query.accept MyVisitor.new

    # outputs:
    # before select
    # 2
    # name
    # age
    # after select

There is a <tt>visit\_XXX</tt> and <tt>end\_visit\_XXX</tt> for every node in the language.

Wrappers for Google DataTable and others
----------------------------------------

Their source code is [here](https://github.com/asterite/rgviz/blob/master/lib/rgviz/table.rb). You can use them to generate the javascript code to implement the wire protocol.

Output Formatters
-----------------

You can use <tt>Rgviz::HtmlRenderer.render(table)</tt> and <tt>Rgviz::CsvRenderer.render(table)</tt> to get a string to render in html or csv output format.

Contributors
------------

* [Brad Seefeld](https://github.com/bradseefeld)
