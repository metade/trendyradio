require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'
require 'json'
require 'erb'
require 'digest/md5'

require 'active_support/cache'
require 'active_support/cache/dalli_store'

RADIO_NETWORKS = [
  'BBC Asian Network',
  'BBC World Service',
]

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

get '/locations/:woeid/trends.jsonp' do |woeid|
  content_type 'application/json'
  response.headers['Cache-Control'] = 'public, max-age=120'
  
  callback = params[:callback] || 'callback'
  "#{callback}(#{aggregate_content(woeid).to_json});"
end

get '/locations/:woeid/trends.json' do |woeid|
  content_type 'application/json'
  response.headers['Cache-Control'] = 'public, max-age=120'
  
  aggregate_content(woeid).to_json
end

# BACK END STUFF

def aggregate_content(woeid)
  data = trends(woeid)
  data['trends'].map do |trend|
    description = trend['description']['text'] if trend['description']
    content = find_content(trend['name'])
    if (content.empty? and description)
      terms = term_extraction(description)
      content = find_content(terms.first) if terms.any?
    end
    { :title => trend['name'],
      :category => trend['category_name'],
      :description => description,
      :first_trended_at => trend['first_trended_at'],
      :last_trended_at => trend['last_trended_at'],
      :content => content
    }
  end
end

def term_extraction(description)
  url = "http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20search.termextract%20where%20context%3D%22#{URI.escape(description)}%22&format=json"
  key = Digest::MD5.hexdigest(url)
  CACHE.fetch(key, :expires_in => 1.hour) do
    puts "FETCHING #{url}"
    begin
      data = JSON.parse(open(url).read)
      if (data['query'] and data['query']['results'] and data['query']['results']['Result'])
        data['query']['results']['Result'] 
      else
        []
      end
    rescue JSON::ParserError
      return []
    rescue OpenURI::HTTPError
      return []
    end
  end
end

def trends(woeid = 23424975)
  url = "http://api.whatthetrend.com/api/v2/trends.json?woeid=#{woeid}"
  CACHE.fetch(url, :expires_in => 2.minutes) do
    puts "FETCHING #{url}"
    begin
      JSON.parse(open(url).read)
    rescue JSON::ParserError
      return []
    end
  end
end

def scrape_search(url, content)
  puts "FETCHING #{url}"
  text = open(url)
  if text
    doc = Hpricot(text)
    (doc/"//div[@class='subSection']/ul/li/div/a").map do |a|
      url = a['href']
      type = a.parent.parent.parent.parent['id'].sub('-content', '')
      next if type == 'around_bbc'
      
      section = (a.parent.parent/"//span[@class='newsSection']").first
      section = section.inner_html.sub(/ \/ $/, '') if section
      
      if type == 'iplayer'
        type = (section.downcase =~ /radio/ or RADIO_NETWORKS.include?(section)) ? 'radio' : 'tv'
        url = "http://www.bbc.co.uk/programmes/#{$1}" if url =~ %r[http://www.bbc.co.uk/iplayer/episode/(\w+)]
      end
      
      image = (a.parent.parent/"//img").first
      image = image['src'] if image
      
      content[type] ||= []
      content[type] << {
        :url => url,
        :type => type,
        :image => image,
        :title => a.inner_html,
        :section => section,
      }
    end
  end
end

def find_content(query)
  key = Digest::MD5.hexdigest(query)
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
