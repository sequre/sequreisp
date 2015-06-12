# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include Aegis::Controller
  #require_permissions
  around_filter :rescue_access_denied

  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user
  
  before_filter :set_time_zone
  before_filter :set_language
  before_filter :check_for_redirect_to_notification
  # uncomment to be able to see error pages in development
  #alias_method :rescue_action_locally, :rescue_action_in_public

  
  # This allows that after an update or create, the user can be redirected
  # to the page visited before entering the form page (edit or new)
  after_filter :store_request_uri, :except => [:edit, :new, :update, :create]

  def default_url_options(options={})
    { :locale => I18n.locale }
  end

  def render_optional_error_file(status_code)
    super unless status_code == :not_found and check_for_redirect_to_notification
  end

  private

  def self.redirections_exceptions
    []
  end

  def check_for_redirect_to_notification
    if ["alerted", "disabled"].include?(request.env['SEQUREISP_STATUS']) and not ApplicationController.redirections_exceptions.include?(action_name.to_sym) and not request.url.include?(SequreispPlugins.internal_ip)
      redirect_to_notification
      true
    else
      false
    end
  end

  # this method has alias_method_chain in traffic_accounting and notification plugins
  def redirect_to_notification
  end

  def store_request_uri
    # skip if it is not html (ie ajax)
    session[:last_visited_uri] = request.request_uri if request.format == :html
  end

  def redirect_back_from_edit_or_to default
    redirect_to(session[:last_visited_uri] || default)
    session[:last_visited_uri] = nil
  end

  def set_language
    Configuration.do_reload
    I18n.locale = if params[:locale] and Configuration::ACCEPTED_LOCALES.include?(params[:locale])
      params[:locale]
    else
      I18n.locale = Configuration.language
    end

  end

  def set_time_zone
    Configuration.do_reload
    Time.zone = Configuration.time_zone
  end


  
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def require_user
    unless current_user
      store_location
      flash[:error] = I18n.t('messages.must_be_logged_in')
      redirect_to login_url
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:error] = I18n.t('messages.must_be_logged_out')
      redirect_back_or_default contracts_path
      return false
    end
  end
  
  def store_location
    session[:return_to] = request.request_uri
  end
  
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
  
  # aegis error rescue
  def rescue_access_denied
    yield
    rescue Aegis::AccessDenied => e 
      #render :text => e.message, :status => :forbidden
      flash[:error] = t 'messages.access_denied'
      if request.referer
        redirect_to :back
      else
        redirect_to :root
      end
  end

  def delete_params_blank_in_massive_setting
    params[:massive_setting].each_pair do |key, value|
      if value.blank?
        params[:massive_setting].delete(key)
      end
    end
  end

end
