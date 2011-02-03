require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'
require 'json'
require 'erb'
require 'base64'

require 'active_support/cache'
require 'active_support/cache/dalli_store'

configure do
  if ENV['cache'] == 'dalli'
    CACHE = ActiveSupport::Cache::DalliStore.new
  else
    CACHE = ActiveSupport::Cache::MemoryStore.new
  end
end

# FRONT END STUFF

get '/' do
  erb :index
end

get '/locations/:woeid/trends.json' do |woeid|
  content_type 'application/json'
  response.headers['Cache-Control'] = 'public, max-age=60'
  
  data = trends(woeid)
  data['trends'].map do |trend|
    description = trend['description']['text'] if trend['description']
    { :title => trend['name'],
      :description => description,
      :first_trended_at => trend['first_trended_at'],
      :last_trended_at => trend['last_trended_at'],
      :content => find_content(trend['name'])
    }
  end.to_json
end

# BACK END STUFF

def trends(woeid = 23424975)
  url = "http://api.whatthetrend.com/api/v2/trends.json?woeid=#{woeid}"
  CACHE.fetch(url, :expires_in => 1.minutes) do
    puts "FETCHING #{url}"
    JSON.parse(open(url).read)
  end
end

def scrape_search(url, content)
  puts "FETCHING #{url}"
  text = open(url)
  if text
    doc = Hpricot(text)
    (doc/"//div[@class='subSection']/ul/li/div/a").map do |a|
      type = a.parent.parent.parent.parent['id'].sub('-content', '')
      next if type == 'around_bbc'
      
      section = (a.parent.parent/"//span[@class='newsSection']").first
      section = section.inner_html.sub(/ \/ $/, '') if section
      
      image = (a.parent.parent/"//img").first
      image = image['src'] if image
      
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

def find_content(query)
  key = Base64.b64encode(query).strip
  content = {}
  CACHE.fetch(key, :expires_in => 1.hour) do
    query_string = URI.escape(%["#{query}"])
    scrape_search(%[http://www.bbc.co.uk/search/?q=#{query_string}], content)
    scrape_search(%[http://www.bbc.co.uk/search/iplayer/?q=#{query_string}], content)
    # scrape_search(%[http://www.bbc.co.uk/search/schedule/?q=#{query_string}], content)
    content.each { |k,v| v.uniq! }
    content
  end
end
