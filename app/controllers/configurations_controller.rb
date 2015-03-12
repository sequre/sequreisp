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

class ConfigurationsController < ApplicationController
  before_filter :require_user
  permissions :configuration
  # GET /configurations
  # GET /configurations.xml
  def index
    @configuration = Configuration.first
    render :action => "edit"
  end

  # GET /configurations/1
  # GET /configurations/1.xml
  def show
    @configuration = Configuration.first
    render :action => "edit"
  end

  # GET /configurations/1/edit
  def edit
    @configuration = Configuration.first
  end

  # PUT /configurations/1
  # PUT /configurations/1.xml
  def update
    @configuration = Configuration.first
    respond_to do |format|
      params[:configuration][:traffic_prio] = params[:traffic_prio].keys.select{|prio| prio != ""}.join(",") if params.has_key?(:traffic_prio)
      if @configuration.update_attributes(params[:configuration])
        # in case that users change language, we need to override locale from params[:locale]
        # before the redirect
        I18n.locale = @configuration.language
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_to(@configuration) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
      end
    end
  end

  def doreload
    Configuration.first.apply_changes
    flash[:notice] = I18n.t('messages.apply_changes_success')
    redirect_to :back
  end

  def ajax_request
    lines = Configuration.get_next_lines_in_command_log(params[:last_line])
    render :json => lines
  end

  def is_apply_changes
    resp = Configuration.is_apply_changes?
    render :json => resp
  end
end
