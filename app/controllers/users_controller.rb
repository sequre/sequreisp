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

class UsersController < ApplicationController
  before_filter :require_user
  before_filter :not_destroy_current_user, :only => [:destroy]
  permissions :users

  # GET /users
  # GET /users.xml
  def index
    @users = User.all(:order => "name ASC")

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @user = object
    render :action => "edit"
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/1/edit
  def edit
    @user = object
  end

  # POST /users
  # POST /users.xml
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(users_path) }
        format.xml  { render :xml => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    @user = object

    respond_to do |format|
      if @user.update_attributes(params[:user])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(users_path)}
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    @user = object
    unless SequreispConfig::CONFIG["demo"] and @user.email == "admin@wispro.co"
      @user.destroy
    end
    respond_to do |format|
      format.html { redirect_back_from_edit_or_to users_url }
      format.xml  { head :ok }
    end
  end
  def generate_token
    respond_to do |format|
      format.json { render :json => {:auth_token => User.new.generate_token }}
    end
  end
  private
  def object
    @object ||= User.find(params[:id])
  end

  def not_destroy_current_user
    if object == current_user
      flash[:error] = t 'controllers.the_user_is_logged'
      redirect_to :back
    end
  end

end
