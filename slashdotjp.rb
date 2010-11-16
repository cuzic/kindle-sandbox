#! ruby -Ku

require "open-uri"
require "uri"
require "cgi"
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

def parse_query(query)
  return query.split("&").
    map { |pair| raise unless /^(.+?)=(.+?)$/ =~ pair; [$1, $2] }.
    map { |key, value| [CGI.unescape(key), CGI.unescape(value)] }.
    inject({}) { |memo, (key, value)| memo[key] = value; memo }
end

def build_query(params)
  return params.
    sort_by { |key, value| key }.
    map { |key, value| [CGI.escape(key), CGI.escape(value)] }.
    map { |key, value|  "#{key}=#{value}" }.
    join("&")
end

def merge_query(url, params)
  uri = URI.parse(url)
  uri.query = build_query(parse_query(uri.query).merge(params))
  return uri.to_s
end


logger = create_logger
http   = create_http_client(logger)

url1 = "http://slashdot.jp/hardware/10/11/14/0416243.shtml"
src1 = http.get(url1)

p url2 = get_canonical_url(src1)
p url3 = merge_query(url2,
  "threshold"   => "1",      # 閾値: 1
  "mode"        => "nested", # ネストする
  "commentsort" => "0")      # 古い順


src3 = http.get(url3)
#File.open("tmp.html", "wb") { |file| file.write(src3) }

doc = Nokogiri.HTML(src3)

doc.xpath("//comment()").remove

=begin
doc.xpath("//text()").
  select { |node| node.to_s.strip.empty? }.
  each   { |node| node.remove }
doc.xpath("//script").remove
doc.xpath("//noscript").remove
doc.xpath("/html/head/meta").remove
doc.xpath("/html/head/link").remove
=end

p title  = doc.xpath("//*[@id='articles']//div[@class='title']/h3/a/text()").text

details = doc.xpath("//*[@id='articles']//div[@class='details']").first
puts "---"
puts details.inner_html

details.xpath("a").each { |node|
  text = node.text
  node.replace(Nokogiri::XML::Text.new(text, doc))
}

puts "---"
puts details.inner_html

details.xpath("text()").each { |node|
  text = node.text
  text.gsub!(/\s+/, " ")
  text.strip!
  node.replace(Nokogiri::XML::Text.new(text, doc))
}

puts "---"
puts details.inner_html

text = ""
details.xpath("node()").each { |node|
  p node
  if node.text?
    text << node.text
  elsif node.element? && node.name == "br"
    text << "\n"
  else
    raise
  end
}
p text

p published  = text[/\A(.+?)\n(.+?)\z/, 1]
p department = text[/\A(.+?)\n(.+?)\z/, 2]

=begin
puts "---"
p published  = details.xpath("br").xpath("following-sibling::*")#.text#.gsub(/\s+/, "")
p department = details.xpath("br").first.next_sibling.text#.gsub(/\s+/, "")
=end

=begin
p author = doc.xpath("//*[@id='articles']//div[@class='details']/a/text()").text

puts "---"
p body = doc.xpath("//*[@id='articles']//div[@class='intro']").inner_html.strip
=end
