
require 'sinatra'
require 'tilt/erubis'
require 'sinatra/contrib'
require 'chartkick'
require 'securerandom'
require 'bcrypt'
require 'pry'

require_relative 'database'

configure do
  enable :sessions
  set :erb, :escape_html => true
  set :session_secret, SecureRandom.hex(64)
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database.rb' 
end


helpers do
  def has_responsibilities? #this is for the editing list and creating an empty hash
    @responsibilities.empty?
  end

  def date_already_exists?(session_id, date)
    @db.dates_logged(session_id).include?(date)
  end

  def commit_to_db(inputs, session_id, date)
    @db.commit_entries(inputs, session_id, date)
    session[:message] = "Responsibilities successfully added."
    redirect "/timesheet"
  end

  def remove_underscores_and_capitalize(word)
    word.gsub(/[_]/, ' ').split(' ').map { |word| word.capitalize }.join(' ') 
  end

  def edit_existing_entries(entry, session_id, date)
    return nil if entry == []
    edited_kv_pairs = test_values(entry)
    kv_pairs = edited_kv_pairs.transform_values(&:to_i)
    @db.overwrite_existing_responsibilities(kv_pairs, session_id, date)
  end

  def extract_date_time_hash(activity_name, session_id)
    @db.extract_date_and_minutes(activity_name, session_id).values.to_h
  end 

  def activity_names(session_id)
    @db.extract_activities(session_id).map { |tuple| tuple["activity_name"]}
  end

  def all_logged_activities(session_id)
    activity_names(session_id).map do |activity_name|
      {name: remove_underscores_and_capitalize(activity_name), data: extract_date_time_hash(activity_name, session_id) }
    end
  end
#charts data as {name_of_activity: basketball, minutes: 45}, 
  def all_logged_minutes(session_id)
    @db.total_minutes_logged(session_id).map do |activity_name|
      activity_name.values
    end.map do |array|
      [remove_underscores_and_capitalize(array[0]), array[1]]
    end
  end

  def extract_average_hours_per_activity(session_id)
    all_logged_minutes(session_id).map do |array|
      [array[0], (minutes_to_hours(array[1].to_i.to_f) / days_logged(session_id)).round(2)]
    end
  end

  def days_logged(session_id)
    @db.dates_logged(session_id).count
  end

  def total_logged_minutes(session_id)
    @db.total_time_used(session_id).to_i
  end

  def accept_entries(hash)
    hash.keep_if {|k, _| (k != '') }
  end

  def validate_entries(hash, username)
    hash.each do |k, v|
      if k.to_s.strip == ''
        session[:message] = "One of your inputs was empty. Please try again."
        redirect "/add_entries"    
      elsif v < 0
        session[:message] = "Only non-negative numbers are allowed. Please try again."
        redirect "/add_entries"   
      elsif k.to_s.count('A-Za-z_ 0-9') != k.to_s.length
        session[:message] = "Names of entries can only contain numbers, letters and spaces.  Please try again."
        redirect "/add_entries"
      end
    end
  end

  def validate_addition(hash, date, username)
    hash.each do |k, v|
      if k.to_s.strip == ''
        session[:message] = "Your additional entry was empty. Please try again."
        redirect '/edit_activities/' + date
      elsif v < 1
        session[:message] = "The time you spend must be greater than zero. Please try again."
        redirect '/edit_activities/' + date 
      elsif k.to_s.count('a-zA-Z_ 0-9') != k.to_s.length
        session[:message] = "Names of entries can only contain numbers, letters and spaces.  Please try again."
        redirect '/edit_activities/' + date
      end
    end
  end

  def format_addition(new_entry)
    new_entry.each { |k, _| k.gsub(/[ ]/, '_') }
  end

  def current_entries(names_and_values, names, standard_entries, personal_entries)
    names_and_values.map.with_index do |hash, idx|
      hash.merge!({"text_on_site": "Edit" + " " + remove_underscores_and_capitalize(names[idx])})
      idx <= 5 ? standard_entries << hash : personal_entries << hash
    end
  end

  def sample_chart
    [ { name: 'Work', data: {'2020-12-16': '500', '2020-12-17': '480', '2020-11-29': "200"}},
      { name: 'Sleep', data: {'2020-12-16': '419', '2020-12-17': '450', '2020-11-29': "480"}},
      { name: 'Eating Meals', data: {'2020-12-16': '45', '2020-12-17': '60', '2020-11-29': "70"}},
      { name: 'Commute To', data: {'2020-12-16': '10', '2020-12-17': '9', '2020-11-29': "8"}},
      { name: 'Commute From', data: {'2020-12-16': '10', '2020-12-17': '12', '2020-11-29': "14"}},
      { name: 'Guitar', data: {'2020-12-16': '60', '2020-12-17': '60', '2020-11-29': "45"}},
      { name: 'Video Games', data: {'2020-12-16': '60', '2020-12-17': '90', '2020-11-29': "30"}},
      { name: 'Side Hustle', data: {'2020-12-16': '25', '2020-12-17': '40', '2020-11-29': "15"}},
      { name: 'Making Meals', data: {'2020-12-16': '60', '2020-12-17': '35', '2020-11-29': "45"}}
    ]
  end

  def sample_pie_chart(arr1, arr2)
    donut = Hash.new
    arr1.each_with_index { |entry, idx|
      donut[entry] = arr2[idx]
    }
    donut
  end

  def test_values(responsibilities)
    responsibilities.keep_if { |_,v| v != '' && v.to_i >= 0}
  end

  def total_minutes(days)
    days*24*60
  end

  def minutes_to_hours(minutes)
    (minutes.to_f / 60.00).round(2)
  end

  def minutes_used(session_id)
    return 0 unless user_has_entry?(session_id)
    total_logged_minutes(session_id) / days_logged(session_id)
  end

  def average_minutes_remaining(session_id)
    return total_minutes(1) unless user_has_entry?(session_id)
    (total_minutes(days_logged(session_id)) - total_logged_minutes(session_id)) / days_logged(session_id)
  end

  def user_has_entry?(session_id)
    days_logged(session_id) > 0
  end

  def user_exists?(username)
    return true if @db.user_already_exists?(username) 
  end
end

#run before EVERY request is made
before do
  @db = DB.new
  session[:responsibilities] ||=[]
  @session_id = session[:id].to_i
  @date = params[:date]
end

after do
  @db.close
end

#inital page
get "/" do
  redirect "/login"
end

#login page
get "/login" do
  erb :login, layout: :login_layout
end

#Verify UN and PW
post "/login" do
  username = params[:username]
  password = params[:password]

  if @db.verify_user(username, password)
    session[:message] = "Welcome back #{username}"
    session[:id] = @db.find_id(username)
    redirect "/timesheet"
  else
    session[:message] = "Invalid Credentials. Please try again."
    erb :login, layout: :layout
  end
end

#Page to Create a New User Account
get "/new_user" do
  @message = "Please register to use the application."

  erb :new_user, layout: :new_user_layout
end

#Register a New User
post "/new_user" do
  username = params[:username]
  password = params[:password]

  if user_exists?(username)
    session[:message] = "Username already exists.  Please try another."
    redirect '/new_user'
  else
    @db.add_new_user(username, password) 
    session[:message] = "Your account has been created successfully."
    redirect "/login"
  end
end

#page to add a responsibility
get "/add_entries" do
  erb :add_entries, layout: :layout
end

#post the list of entries to the DB
post "/add_entries" do
    inputs = {
      work: params[:work].to_i,
      sleep: params[:sleep].to_i,
      commute_to: params[:commute_to].to_i,
      commute_from: params[:commute_from].to_i,
      meal_prep: params[:meal_prep].to_i,
      meals: params[:eating_meals].to_i,
      params[:hobby1] => params[:hobby1time].to_i,
      params[:hobby2] => params[:hobby2time].to_i,
      params[:hobby3] => params[:hobby3time].to_i,
      params[:hobby4] => params[:hobby4time].to_i,
      params[:hobby5] => params[:hobby5time].to_i
    }

    date = params[:date]
    
    valid_entries = accept_entries(inputs)
    validated_pairs = validate_entries(valid_entries, @username)

    commit_to_db(validated_pairs, @session_id, date) unless date_already_exists?(@session_id, date)
    session[:message] = "Date already exists.  Choose 'Edit Existing Entries'."
    redirect "/timesheet"
end

get "/timesheet" do
  @chart = all_logged_activities(@session_id) 

  @minutes_per_day =  minutes_used(@session_id)
  @average_hours_used = minutes_to_hours(@minutes_per_day)
  @average_minutes_remaining = average_minutes_remaining(@session_id)
  @hours_remaining = minutes_to_hours(@average_minutes_remaining)

  @daily_activity_hours = extract_average_hours_per_activity(@session_id)
  
  @total_minutes = all_logged_minutes(@session_id)
  @hours_used = {'Hours Remaining': @hours_remaining, 'Hours Used':@average_hours_used }
  
  erb :timesheet, layout: :layout
end

#which day to edit?
get "/choose_date" do
  @dates = @db.dates_available(@session_id).map { |tuple| tuple["date"] }.sort

  erb :choose_date, layout: :layout
end

#edit page for an existing set of entries
get "/edit_activities/:date" do
  @date = params[:date]
  @standard_entries = []
  @personal_entries = []

  names_and_values = @db.names_and_values(@session_id, @date).map { |tuple| tuple}
  names = @db.extract_names(@session_id, @date).map { |tuple| tuple["activity_name"]}

  current_entries(names_and_values, names, @standard_entries, @personal_entries)
  erb :edit_activities, layout: :layout
end

#overwrite existing entries of a given date
post "/edit_activities/:date" do
  date = params[:date]

  new_entry = {params[:add_name] => params[:add_value].to_i}
  validate_addition(new_entry, date, @username)

  new_entry = format_addition(new_entry)

  @names_values_text = @db.names_and_values(@session_id, date).map { |tuple| tuple}
  edits = @names_values_text.map { |hash| 
  [hash["activity_name"], params[hash["activity_name"].to_sym]]}.to_h

  edit_existing_entries(edits, @session_id, date)
  @db.commit_entries(new_entry, @session_id, date)

  session[:message] = "Information for #{date} updated."
  redirect '/timesheet'
end

get "/sample_page" do
  @username = "Sample User"

  @chart = sample_chart

  sample_minutes = sample_chart.map { |hash| hash[:data].values.map(&:to_i).inject(:+) }.flatten
  sample_entries = sample_chart[0][:data].size
  @total_minutes_logged = sample_chart.map {|hash| hash[:data].values.map(&:to_i).inject(:+)}.inject(:+)

  @minutes_per_day =  sample_minutes.inject(:+) / sample_entries
  @average_hours_used = minutes_to_hours(@minutes_per_day)
  @average_minutes_remaining = (24*60) - @minutes_per_day
  @hours_remaining = minutes_to_hours(@average_minutes_remaining)
  
  chart_names = sample_chart.map {|hash| hash[:name]}
  chart_values = sample_minutes

  @daily_activity_hours = sample_chart.map do |hash|
    [hash[:name], ((hash[:data].values.map(&:to_i).inject(:+) / sample_entries).to_f./60.round(2))]
  end

  @hours_used = {'Hours Remaining': @hours_remaining, 'Hours Used':@average_hours_used }
  @total_minutes = sample_pie_chart(chart_names, chart_values)

  erb :sample, layout: :sample_page_layout
end

#choose dates to delete
get "/delete_date" do
  @dates = @db.dates_available(@session_id).map { |tuple| tuple["date"] }.sort
  erb :delete_date, layout: :layout
end

post "/delete_date" do
  date_choices = [
    params[:date0], params[:date1], params[:date2], params[:date3], params[:date4], 
    params[:date5], params[:date6], params[:date7], params[:date8], params[:date9]
]
  date_choices.each do |date|
    @db.delete_entry(@session_id, date)
  end
  session[:message] = "Your timesheet has been updated."
  redirect "/timesheet"
end

post "/delete_single_entry/:date/:activity_name" do
  activity_name = params[:activity_name].to_s
  date = params[:date].to_s
  @db.delete_single_item(@session_id, activity_name, date)
  session[:message] = "Entry successfully deleted."
  redirect "/edit_activities/#{date}"
end

post "/cancel_delete" do
  session[:message] = "You information was not deleted."
  redirect "/timesheet"
end

post "/destroy" do

  @db.delete_values(@session_id)
  session[:message] = "You have deleted all your entries."
  redirect "/timesheet"
end

post "/signout" do
  session.clear
  session[:message] = "You have successfully signed out."
  redirect "/"
end