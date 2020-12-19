require 'pg'
require 'bcrypt'

class DB
  def initialize
    @connection = if Sinatra::Base.production?
        PG.connect(ENV['DATABASE_URL'])
      else
        PG.connect(dbname: 'automate')
      end
  end

  def user_already_exists?(username)
    sql = "SELECT username FROM users;"
    result = @connection.exec_params(sql)
    return true if result.field_values('username').include?(username)
    false
  end

  def validate_sign_in(username)
    sql = "SELECT username FROM users;"
    result = @connection.exec_params(sql)
    return false unless result.field_values('username').include?(username)
    true
  end

  def verify_user(username, user_password)
    sql = "SELECT * FROM users WHERE username = $1;"
    result = @connection.exec_params(sql, [username])
    return false if result.ntuples == 0

    BCrypt::Password.new(result[0]["password"]) == user_password
  end

  def add_new_user(username, password)
    sql = <<~SQL
    INSERT INTO users (username, password) VALUES
    ($1, $2);
    SQL

    password = BCrypt::Password.create(password)

    @connection.exec_params(sql, [username, password])
  end

  def find_username(session_id)
    sql = "SELECT username FROM users WHERE id = $1"
    result = @connection.exec_params(sql, [session_id]).values
    result[0][0]
  end

  def find_id(username)
    sql = "SELECT id FROM users WHERE username = $1;"
    result = @connection.exec_params(sql, [username])
    result[0]["id"].to_i
  end

  def commit_entries(responsibilities, session_id, date)
    sql = "INSERT INTO activities (activity_name, minutes_used, user_id, date)
      VALUES ($1, $2, $3, $4)"
      responsibilities.each do |k,v|
        @connection.exec_params(sql, [k.to_s, v, session_id, date])
      end
  end

  def overwrite_existing_responsibilities(edited_kv_pairs, session_id, date)
    sql = "UPDATE activities SET minutes_used = $1 WHERE activity_name = $2 AND user_id = $3 AND date = $4;"
    edited_kv_pairs.each do |k,v|
      @connection.exec_params(sql, [v.to_i, k, session_id, date])
    end
  end

  def total_time_used(session_id)
    sql = "SELECT SUM(minutes_used) FROM activities WHERE user_id = $1"
    result = @connection.exec_params(sql, [session_id]).values
    result[0][0]
  end

  def total_logged_actions(session_id)
    sql = "SELECT DISTINCT COUNT(date) FROM activities WHERE user_id = $1"
    result = @connection.exec_params(sql, [session_id]).values
    result[0][0]
  end

  def dates_logged(session_id)
    sql = "SELECT DISTINCT date FROM activities WHERE user_id = $1"
    @connection.exec_params(sql, [session_id]).values.flatten
  end

  def show_table(session_id)
    if session_id == "test"
      sql = "SELECT * FROM ACTIVITIES WHERE user_id = 2" #I will have to modify this since 'test' is te name fo a user, their id is 2
      @connection.exec_params(sql).each { |data| data }
    else
      sql = "SELECT * FROM activities WHERE user_id = $1"
      @connection.exec_params(sql, [session_id])
    end
  end

  def names_and_values(session_id, date)
    sql = "SELECT activity_name, minutes_used FROM activities WHERE user_id = $1 AND date = $2"
    @connection.exec_params(sql, [session_id, date])
  end

  def dates_available(session_id)
    sql = "SELECT date FROM activities WHERE user_id = $1 GROUP BY date"
    @connection.exec_params(sql, [session_id])
  end

  def extract_activities(session_id)
    sql = "SELECT activity_name FROM activities WHERE user_id = $1 GROUP BY activity_name"
    @connection.exec_params(sql, [session_id])
  end

  def extract_names(session_id, date)
    sql = "SELECT activity_name FROM activities WHERE user_id = $1 AND date = $2"
    @connection.exec_params(sql, [session_id, date])
  end

  def extract_minutes_per_activity(session_id, date)
    sql = "SELECT minutes_used FROM activities WHERE user_id = $1 AND date = $2"
    @connection.exec_params(sql, [session_id, date])
  end

  def extract_date_and_minutes(activity_name, session_id)
    sql = "SELECT date, minutes_used FROM activities WHERE activity_name = $1 and user_id = $2"
    @connection.exec_params(sql, [activity_name, session_id])
  end

  def delete_single_item(session_id, name, date)
    sql = "DELETE FROM activities WHERE user_id = $1 AND activity_name = $2 AND date = $3"
    @connection.exec_params(sql, [session_id, name, date])
  end

  def delete_entry(session_id, date)
    sql = "DELETE FROM activities WHERE user_id = $1 AND date = $2"
    @connection.exec_params(sql, [session_id, date])
  end

  def destroy_all_entries(session_id)
      sql = "DELETE FROM activities WHERE user_id= $1;"
      @connection.exec_params(sql, [session_id])
  end

end
