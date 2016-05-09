class Api::ApiController < ApplicationController
	before_filter :check_ssl, :if => 'Rails.env.production?'
	before_filter :authenticate
  protected

  def check_ssl
    request.ssl? || render_unauthorized
  end
  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
		authorized_user = nil
		token = token_and_options(request)
		unless token.nil?
	    User.all(:conditions => 'api_enabled = 1 and auth_token is not null').each do |u|
				authorized_user = u if secure_compare(u.auth_token, token[0])
			end
		end
		if authorized_user.nil?
			false
		else
			@current_user = authorized_user
		end
  end

  def render_unauthorized
    self.headers['WWW-Authenticate'] = 'Token realm="Application"'
    render :json =>  'Bad credentials', :status => 401
  end

	# Parses the token and options out of the token authorization header. If the header looks like this:
	#   Authorization: Token token="abc", nonce="def"
	# Then the returned token is "abc", and the options is {:nonce => "def"}
	# request - ActionController::Request instance with the current headers.
	# Returns an Array of [String, Hash] if a token is present. Returns nil if no token is found.
  def token_and_options(request)
    if header = authorization(request).to_s[/^Token (.*)/]
      values = $1.split(',').
        inject({}) do |memo, value|
          value.strip!                      # remove any spaces between commas and values
          key, value = value.split(/\=\"?/) # split key=value pairs
          value.chomp!('"')                 # chomp trailing " in value
          value.gsub!(/\\\"/, '"')          # unescape remaining quotes
          memo.update(key => value)
        end
      [values.delete("token"), values.with_indifferent_access]
    end
  end
  def authorization(request)
    request.headers['Authorization']  # ||
#    request.env['X-HTTP_AUTHORIZATION'] ||
#    request.env['X_HTTP_AUTHORIZATION'] ||
#    request.env['REDIRECT_X_HTTP_AUTHORIZATION']
  end
  def secure_compare(a, b)
    if a.length == b.length
      result = 0
      for i in 0..(a.length - 1)
        result |= a[i] ^ b[i]
      end
      result == 0
    else
      false
    end
  end

end
