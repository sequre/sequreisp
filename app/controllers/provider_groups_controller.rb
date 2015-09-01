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

class ProviderGroupsController < ApplicationController
  before_filter :require_user
  permissions :provider_groups

  # GET /provider_groups
  # GET /provider_groups.xml
  def index
    @provider_groups = ProviderGroup.all(:order => "name ASC")

    @graphs = @provider_groups.map{ |pg| InterfaceGraph.new(pg, "provider_group_instant") }

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @provider_groups }
    end
  end

  # GET /provider_groups/1
  # GET /provider_groups/1.xml
  def show
    @provider_group = object
    @periods = InterfaceSample::CONF_PERIODS.size
    @graphs = {}

    InterfaceGraph.supported_graph(@provider_group).each do |graph_name|
      @graphs[graph_name] = InterfaceGraph.new(@provider_group, graph_name)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @provider_group }
    end
  end

  # GET /provider_groups/new
  # GET /provider_groups/new.xml
  def new
    @provider_group = ProviderGroup.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @provider_group }
    end
  end

  # GET /provider_groups/1/edit
  def edit
    @provider_group = object
  end

  # POST /provider_groups
  # POST /provider_groups.xml
  def create
    @provider_group = ProviderGroup.new(params[:provider_group])

    respond_to do |format|
      if @provider_group.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(provider_groups_path) }
        format.xml  { render :xml => @provider_group, :status => :created, :location => @provider_group }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @provider_group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /provider_groups/1
  # PUT /provider_groups/1.xml
  def update
    @provider_group = object

    respond_to do |format|
      if @provider_group.update_attributes(params[:provider_group])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(provider_groups_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @provider_group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /provider_groups/1
  # DELETE /provider_groups/1.xml
  def destroy
    @provider_group = object

    if @provider_group.plans.count > 0
      flash[:error] = t 'messages.provider_group.could_not_be_deleted', :count => @provider_group.plans.count
      redirect_to :back
    else
      @provider_group.destroy
      redirect_back_from_edit_or_to provider_groups_url
    end
  end
  def instant
    @provider_group = object
    respond_to do |format|
      format.json { render :json => @provider_group.instant }
    end
  end
  def graph
    @provider_group = object
    @graph = Graph.new(:class => object.class.name, :id => object.id)
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @graph }
    end
  end
  private
  def object
    @object ||= ProviderGroup.find(params[:id])
  end
end
