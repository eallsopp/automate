CREATE TABLE users (
  id serial PRIMARY KEY,
  username text UNIQUE NOT NULL,
  password text NOT NULL
);

CREATE TABLE activities (
  id serial PRIMARY KEY,
  activity_name text NOT NULL,
  minutes_used integer NOT NULL,
  date date NOT NULL default CURRENT_DATE,
  user_id integer REFERENCES users (id)
);
