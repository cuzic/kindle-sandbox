#! ruby -Ku
# coding: utf-8

require "rubygems"
require "log4r"
require "nokogiri"

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

def get_canonical_url(src)
  doc = Nokogiri.HTML(src)
  url = doc.xpath("/html/head/link[@rel='canonical']").first[:href]
  return url
end

def remove_unnecessary_elements(doc)
  doc.xpath("//comment()").remove
  doc.xpath("//script").remove
  doc.xpath("//noscript").remove
  doc.xpath("//text()").
    select { |node| node.to_s.strip.empty? }.
    each   { |node| node.remove }
end

def parse(src)
  doc = Nokogiri.HTML(src)
  remove_unnecessary_elements(doc)
puts doc.to_xml(:indent => 1, :encoding => "UTF-8")
end

def main(argv)
  logger = create_logger
  http   = create_http_client(logger)

  original_url = argv[0]
  original_src = http.get(original_url)
  canonical_url = get_canonical_url(original_src)
  canonical_src = http.get(canonical_url)

  parse(canonical_src)
end

main(ARGV)
