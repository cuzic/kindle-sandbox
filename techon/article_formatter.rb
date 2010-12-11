# coding: utf-8

require "erb"

module TechOn
  module ArticleFormatter
    def self.format(article)
      filename = File.join(File.dirname(__FILE__), "template.xhtml.erb")
      result = erb_result filename, article
      return result
    end
  end
end
