require "instagram"
require "yaml"
require "haml"
require "sass"

enable :sessions

CALLBACK_URL = "http://localhost:4567/oauth/callback"
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
    html += "<br/>#{self.location_name}<br/>"
    return html
  end
end

class Instaplaces < Sinatra::Base; end;

class Instaplaces
  get "/" do
    html = "<h1>Instaplaces</h1>"
    html << "<p>Instaplaces is a tool for finding cool things around you that you may have "
    html << "never knew existed. By using your phone's GPS or your computer's location, I've listed "
    html << "below the places near you where people are taking pictures most frequently using the "
    html << "popular Instagram app. Made for you with love "
    html << "by <a href='http://www.twitter.com/justinxreese'>@justinxreese</a></p>"
    # html << "<input type='text' id='latlnginput'></input>"
    html << "<div id='pictures'>Please allow geolocation services...</div>"
    haml html
  end

  get '/stylesheets/style.css' do
    sass :style
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
  
  get "/feed" do
    client = Instagram.client(:access_token => session[:access_token])
    user = client.user
  
    html = "<h1>#{user.username}'s recent photos</h1>"
    for media_item in client.user_recent_media
      html << "<img src='#{media_item.images.thumbnail.url}'>"
    end
    html
  end
  
  get "/nearby/:lat_lng" do
    client = Instagram.client(:access_token => session[:access_token])
  
    # loc_string = "40.405784,-79.908714"
    loc_string = params[:lat_lng]
    lat = loc_string.split(",")[0]
    lng = loc_string.split(",")[1]
    html = "<h3>Photos near #{lat},#{lng}</h3>"
  
    media_items = client.media_search(lat,lng,{:count =>100, :distance => 5000, :max_timestamp => Time.now.to_i, :min_timestamp => (Date.today - (2*365)).to_time.to_i})
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
        html << "<div class='number-posts'>#{posts.count}</div> Pics"
        html << "</div>"
        posts.each do |post|
          html << post.to_html
        end
      else
        html << "<div class='title'>"
        html << "<div class='location-name'>N/A</div>"
        html << "<div class='number-posts'>#{posts.count}</div> Pics"
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
