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

class UserSessionsController < ApplicationController
  layout "login"
  #before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  skip_permissions  
 
  def new
    redirect_to contracts_path if current_user
    @user_session = UserSession.new
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      redirect_back_or_default contracts_path
    else
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy
    #redirect_to new_user_session_url
    redirect_to root_url
  end
end
