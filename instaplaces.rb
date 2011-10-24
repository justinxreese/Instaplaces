require 'instagram'
require 'yaml'
require 'haml'
require 'sass'
require 'json'

enable :sessions

CALLBACK_URL = "http://instaplac.es/oauth/callback"
key_file = YAML.load_file('config/keys.yml')

Instagram.configure do |config|
  config.client_id = key_file['client_id'] 
  config.client_secret = key_file['client_secret'] 
end

class InstagramPost 
  attr_accessor :link, :thumb_url, :location_name, :location_lat, :location_lng

  def to_html
    html = "<a href='#{self.link}'>"
    html += "<img src='#{self.thumb_url}' title='#{self.location_name} - #{self.location_lat},#{self.location_lng}'>"
    html += "</a>"
    html += "<br/><br/>"
  end

  def to_json
   {link:self.link, thumb_url:self.thumb_url, location_name:self.location_name, 
    location_lat:self.location_lat, location_lng:self.location_lng}.to_json
  end
end

class Instaplaces < Sinatra::Base; end;

class Instaplaces
  get "/" do
    # html << "<input type='text' id='latlnginput'></input>"
    haml "<div id='pictures'>Please allow geolocation services...</div>"
  end

  get '/stylesheets/style.css' do
    sass :style
  end
  
  get '/camera.png' do
    send_file('public/camera.png')
  end

  get "/needs_instagram_auth" do
    haml '<a href="/oauth/connect">Connect with Instagram</a>'
  end
  
  get "/oauth/connect" do
    redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
  end
  
  get "/oauth/callback" do
    response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
    session[:access_token] = response.access_token
    redirect "/feed"
  end
  
  get "/error/:intent" do
    if params[:intent] == 'web'
      html = "<div id='error'>Sorry, something went wrong on Instagram's side. Try reloading.<div>"
      haml html, :layout => (request.xhr? ? false : :layout)
    elsif params[:intent] == 'api'
      {error:"Instagram service error"}.to_json
    end
  end
  
  get "/feed" do
    client = Instagram.client(:access_token => session[:access_token])
    user = client.user
  
    html = "<h1>#{user.username}'s recent photos</h1>"
    for media_item in client.user_recent_media
      html << "<img src='#{media_item.images.thumbnail.url}'>"
    end
    html
  end
  
  get "/api/nearby/:lat_lng" do
    client = Instagram.client(:access_token => session[:access_token])

    loc_string = params[:lat_lng]
    lat = loc_string.split(",")[0]
    lng = loc_string.split(",")[1]
  
    begin
      media_items = client.media_search(lat,lng,{:count =>100, :distance => 5000, 
        :max_timestamp => Time.now.to_i, :min_timestamp => (Date.today - (2*365)).to_time.to_i})
    rescue
      redirect "/error/api" 
    end
    places = Hash.new
    media_items.each do |media_item|
      places[media_item.location.id] = [] unless places[media_item.location.id]
      post = InstagramPost.new
      post.link = media_item.link 
      post.thumb_url = media_item.images.thumbnail.url
      post.location_name = media_item.location.name 
      post.location_lat = media_item.location.latitude 
      post.location_lng = media_item.location.longitude
      places[media_item.location.id] << post
    end # media_item
  
    places.collect{|id,posts|posts.collect{|x| x.to_json}}.to_json
  end

  get "/nearby/:lat_lng" do
    client = Instagram.client(:access_token => session[:access_token])
  
    # loc_string = "40.405784,-79.908714"
    loc_string = params[:lat_lng]
    lat = loc_string.split(",")[0]
    lng = loc_string.split(",")[1]
    html = "<h3>Photos near <a href='/nearby/#{lat},#{lng}'>#{lat},#{lng}</a></h3>"
  
    begin
      media_items = client.media_search(lat,lng,{:count =>100, :distance => 5000, 
        :max_timestamp => Time.now.to_i, :min_timestamp => (Date.today - (2*365)).to_time.to_i})
    rescue
      redirect "/error/web"
    end
    places = Hash.new
    media_items.each do |media_item|
      places[media_item.location.id] = [] unless places[media_item.location.id]
      post = InstagramPost.new
      post.link = media_item.link 
      post.thumb_url = media_item.images.thumbnail.url
      post.location_name = media_item.location.name 
      post.location_lat = media_item.location.latitude 
      post.location_lng = media_item.location.longitude
      places[media_item.location.id] << post
    end # media_item
  
    places.sort{|a, b| -1*(a[1].count <=> b[1].count)}.each do |place_id,posts|
      html << "<div class='place'>"
      if place_id
        html << "<div class='title'>"
        html << "<div class='location-name'>#{client.location(place_id).name}</div>"
        pic_word = posts.count == 1 ? "Pic" : "Pics"
        html << "<div class='number-posts'>#{posts.count}</div> #{pic_word}"
        html << "</div>"
        posts.each do |post|
          html << post.to_html
        end
      else
        html << "<div class='title'>"
        html << "<div class='location-name'>N/A</div>"
        pic_word = posts.count == 1 ? "Pic" : "Pics"
        html << "<div class='number-posts'>#{posts.count}</div> #{pic_word}"
        html << "</div>"
        posts.each do |post|
          html << post.to_html
        end
      end
      html << "</div>"
    end
    haml html, :layout => (request.xhr? ? false : :layout)
  end
end
