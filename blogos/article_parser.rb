# coding: utf-8

require "uri"
require "rubygems"
require "nokogiri"

module Blogos
  module ArticleParser
    def self.extract(src, url)
      @doc = Nokogiri.HTML(src)
      return {
        "url"            => url,
        "title"          => self.extract_title(src),
        "published_time" => self.extract_published_time(src),
        "author"         => self.extract_author(src),
        "images"         => self.extract_images(src, url),
        "body"           => self.extract_body(src, url),
        "next_link"      => self.extract_next_link(src, url)
      }
    end

    def self.extract_title(src)
      doc   = @doc
      title = doc.xpath('//div[@class="article-title"]/h1/text()').text.strip
      return title
    end

    def self.extract_published_time(src)
      doc  = @doc
      time = doc.xpath('//p[@class="article-date"]/text()').text.strip
      if /\A(\d\d\d\d)年(\d\d)月(\d\d)日(\d\d)時(\d\d)分\z/ =~ time
        return Time.local(*$~[1..5].map{|i| i.to_i})
      else
        return nil
      end
    end

    def self.extract_author(src)
      doc    = @doc
      author = doc.xpath('//p[@class="author"]/text()').text.strip
      return author
    end

    def self.extract_images(src, url)
      doc  = @doc
      divs = doc.xpath('//*[@id="kiji"]/div[@class="bpbox_right"]/div[@class="bpimage_set"]')
      return divs.map { |div|
        path    = div.xpath('./div[@class="bpimage_image"]//img').first[:src]
        url     = URI.join(url, path).to_s
        caption = div.xpath('./div[@class="bpimage_caption"]//text()').text.strip
        {"url" => url, "caption" => caption}
      }
    end

    def self.extract_body(src, url)
      doc = @doc

      # 全体の不要な要素を削除
      doc.xpath("//comment()").remove
      doc.xpath("//script").remove
      doc.xpath("//noscript").remove
      doc.xpath("//text()").
        select { |node| node.text.strip.empty? }.
        each   { |node| node.remove }

      # 本文のdiv要素を取得
      body = doc.xpath('//div[@class="article"]').first
      # 本文内の相対リンクをURLに置換
      body.xpath('.//a').each { |anchor|
        path = anchor[:href].strip
        url  = URI.join(url, path).to_s
        anchor.set_attribute("href", url)
        anchor.remove_attribute "onclick"
     }

      return body.to_xml(:indent => 0, :encoding => "UTF-8")
    end

    def self.extract_next_link(src, url)
      doc = @doc
      next_link = doc.xpath('//div[@class="article-page"]//td[@class="link-next"]/a').first[:href].strip rescue nil
      return next_link
    end
  end
end
