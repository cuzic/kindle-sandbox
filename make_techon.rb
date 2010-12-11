#! ruby -Ku
# coding: utf-8

require "cgi"
require "erb"
require "yaml"
require "rubygems"
require "uuid"
require "zip/zip"

$: << File.join(File.dirname(__FILE__), "lib")
require "http/factory"
require "http/message_pack_store"

def create_http_client(logger)
  store = HttpClient::MessagePackStore.new(File.join(File.dirname(__FILE__), "cache"))
  return HttpClient::Factory.create_client(
    :logger   => logger,
    :interval => 1.0,
    :store    => store)
end

def create_logger
  formatter = Log4r::PatternFormatter.new(:pattern => "%d [%l] %M", :date_pattern => "%H:%M:%S")
  outputter = Log4r::StderrOutputter.new("", :formatter => formatter)
  logger = Log4r::Logger.new($0)
  logger.add(outputter)
  logger.level = Log4r::DEBUG
  return logger
end

def file_read filename
  return File.open(filename,        "rb") { |file| file.read }
end

def erb_result erb_filename, hash = nil, &block
  template = file_read erb_filename

  obj = Object.new
  m = Module.new do |m|
    if block_given? then
      define_method :call, block
    end
    if hash then
      hash.each do |key, value|
        define_method key.to_sym do
          value
        end
      end
    end
  end
  obj.extend ERB::Util
  obj.extend m
  obj.call if block_given?
  if hash then
    hash.each do |key, value|
      obj.instance_variable_set "@#{key}", value
    end
  end
  b = obj.instance_eval { binding}
  erb = ERB.new(template, nil, "-")
  erb.filename = erb_filename
  result = erb.result( b )
  return result
end

yaml_filename = ARGV.shift
yaml_filename ||= "techon.yaml"
logger = create_logger
http   = create_http_client(logger)

manifest  = YAML.load_file(yaml_filename)
require manifest["require"]
uuid      = manifest["uuid"]      || UUID.new.generate
title     = manifest["title"]     || Time.now.strftime("%Y-%m-%d %H:%M:%S")
author    = manifest["author"]    || "Unknown"
publisher = manifest["publisher"] || nil
urls      = manifest["urls"].split(/\s+/)
epub_filename  = manifest["epub_filename"]
klass     = self.class.const_get(manifest["classname"])
Article   = klass.const_get("Article")

image_count = 0

articles = urls.each_with_index.map { |url, index|
  article = Article.get(http, url)
  article["id"] = "text#{index + 1}"
  article["images"].each { |image|
    image_count += 1
    image["id"] = "image#{image_count}"
  }
  article
}.sort_by { |article| article["published_time"] }


mimetype        = file_read "template/mimetype"
container_xml   = file_read "template/container.xml"

opf_items = [
  {:id => "toc", :href => "toc.xhtml", :type => "application/xhtml+xml"},
]
articles.each { |article|
  opf_items << {:id => article["id"], :href => article["filename"], :type => article["type"]}
  article["images"].each { |image|
    opf_items << {:id => image["id"], :href => image["filename"], :type => image["type"]}
  }
}

opf_itemrefs = [{:idref => "toc"}]
opf_itemrefs += articles.map { |article| {:idref => article["id"]} }

content_opf = erb_result "template/content.opf.erb" do
  @uuid      = CGI.escapeHTML(uuid)
  @title     = CGI.escapeHTML(title)
  @author    = CGI.escapeHTML(author)
  @publisher = CGI.escapeHTML(publisher)
  @items     = opf_items
  @itemrefs  = opf_itemrefs
end

toc_ncx = erb_result "template/toc.ncx.erb" do
  @uuid      = CGI.escapeHTML(uuid)
  @title     = CGI.escapeHTML(title)
  @author    = CGI.escapeHTML(author)
  @nav_points = articles.map { |article|
    { :label_text => article["title"],
      :content_src => article["filename"]}
  }
end

toc_xhtml = erb_result "template/toc.xhtml.erb" do
  @articles = articles.map { |article|
    [CGI.escapeHTML(article["title"]),
        CGI.escapeHTML(article["filename"])]
  }
end


filename = epub_filename
File.unlink(filename) if File.exist?(filename)
Zip::ZipFile.open(filename, Zip::ZipFile::CREATE) { |zip|
  def zip.output filename, body
    self.get_output_stream filename do |io|
      io.write body
    end
  end
  # FIXME: mimetypeは無圧縮でなければならない
  # FIXME: mimetypeはアーカイブの先頭に現れなければならない
  zip.output "mimetype", mimetype
  zip.output "META-INF/container.xml", container_xml
  zip.output "OEBPS/content.opf", content_opf
  zip.output "OEBPS/toc.ncx", toc_ncx
  zip.output "OEBPS/toc.xhtml", toc_xhtml
  articles.each { |article|
    zip.output"OEBPS/" + article["filename"], article["file"]
  }
  articles.each { |article|
    article["images"].each { |image|
      zip.output"OEBPS/" + image["filename"], image["file"]
    }
  }
}
