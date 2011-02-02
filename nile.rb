require 'rubygems'
require 'json'
require 'open-uri'
require 'hpricot'
require 'pp'

require 'sqlite_cache'
$cache = SqliteCache.new('cache.db')
def copen(url)
  $cache.do_cached(url) do
    puts "FETCHING: #{url}"
    begin
      open(url).read
    rescue
      return nil
    end
  end
end


woeid = 23424975
url = "http://api.whatthetrend.com/api/v2/trends.json?woeid=#{woeid}"
data = JSON.parse(copen(url))
# pp data

def scrape_search(url, content)
  text = copen(url)
  if text
    doc = Hpricot(text)
    (doc/"//div[@class='subSection']/ul/li/div/a").map do |a|
      type = a.parent.parent.parent.parent['id'].sub('-content', '')
      next if type == 'around_bbc'
      
      section = (a.parent.parent/"//span[@class='newsSection']").first
      section = section.inner_html.sub(/ \/ $/, '') if section
      
      image = (a.parent.parent/"//img").first['src']
      
      content[type] ||= []
      content[type] << {
        :url => a['href'],
        :type => type,
        :image => image,
        :title => a.inner_html,
        :section => section,
      }
    end
  end
end

trends = data['trends'].map do |trend|
  description = trend['description']['text'] if trend['description']
  p [trend['name'], description]
  
  # url = "http://search.bbc.co.uk/suggest?q=#{URI.escape(trend['name'])}&format=blq-1&scope=iplayer"
  # search_results = JSON.parse(copen(url))
  # pp search_results
  
  content = {}
  query = URI.escape(%["#{trend['name']}"])
  scrape_search(%[http://www.bbc.co.uk/search/?q=#{query}], content)
  scrape_search(%[http://www.bbc.co.uk/search/iplayer/?q=#{query}], content)
  scrape_search(%[http://www.bbc.co.uk/search/schedule/?q=#{query}], content)
  content.each { |k,v| v.uniq! }
  
  { :title => trend['name'],
    :description => description,
    :first_trended_at => trend['first_trended_at'],
    :last_trended_at => trend['last_trended_at'],
    :content => content
  }
end
pp trends
File.open('nile.json', 'w') do |file|
  file.puts("loadTrends(#{trends.to_json})")
end

