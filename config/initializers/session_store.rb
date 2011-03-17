# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_sequreisp_session',
  :secret      => '1c4bf270642d3f6619185181bbe54e7d53ff2c5af6d11332e11a6dc13edf223e5785df7f86fbdca74d7d871f3c2702dd08d59d34afe835b72abfa0d9c14847f5'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
