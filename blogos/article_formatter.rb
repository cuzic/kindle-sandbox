# coding: utf-8

require "erb"

module Blogos
  module ArticleFormatter
    def self.format(article)
      filename = File.join(File.dirname(__FILE__), "template.xhtml.erb")
      result = erb_result filename, article
      return result
    end
  end
end
