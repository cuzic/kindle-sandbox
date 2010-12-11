# coding: utf-8

require "digest/md5"
require File.join(File.dirname(__FILE__), "article_parser")
require File.join(File.dirname(__FILE__), "article_formatter")

module Blogos
  module Article
    def self.get(http, url)
      curl    = self.get_canonical_url(http, url)
      article = {}
      begin
        src     = http.get(curl)
        one_page = ArticleParser.extract(src, curl)
        curl = one_page["next_link"]
        article.update(one_page) do |key, lhs, rhs|
          case
          when key == "body"
            lhs + "\n" + rhs
          when lhs
            lhs
          else
            rhs
          end
        end
      end while curl

      if article["images"] then
        article["images"].each { |image|
            filename, type =
                case image["url"]
                when /\.jpg$/i then
                    [Digest::MD5.hexdigest(image["url"]) + ".jpg",
                        "image/jpeg"]
                else raise("unknown type")
                end
            image["file"]     = http.get(image["url"])
            image["filename"] = filename
            image["type"]     = type
        }
      end

      article["file"]     = ArticleFormatter.format(article)
      article["filename"] = Digest::MD5.hexdigest(article["url"]) + ".xhtml"
      article["type"]     = "application/xhtml+xml"

      return article
    end

    def self.get_canonical_url(http, url)
      return url
    end
  end
end
