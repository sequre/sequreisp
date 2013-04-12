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

class PlansController < ApplicationController
  before_filter :require_user
  permissions :plans
  # GET /plans
  # GET /plans.xml
  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Plan.search(params[:search])
    @plans = @search.paginate(:page => params[:page],:per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @plans }
    end
  end

  # GET /plans/1
  # GET /plans/1.xml
  def show
    @plan = object
    render :action => "edit"
  end

  # GET /plans/new
  # GET /plans/new.xml
  def new
    @plan = Plan.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @plan }
    end
  end

  # GET /plans/1/edit
  def edit
    @plan = object
  end

  # POST /plans
  # POST /plans.xml
  def create
    @plan = Plan.new(params[:plan])

    respond_to do |format|
      if @plan.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(plans_path) }
        format.xml  { render :xml => @plan, :status => :created, :location => @plan }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @plan.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /plans/1
  # PUT /plans/1.xml
  def update
    @plan = object

    respond_to do |format|
      if @plan.update_attributes(params[:plan])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(plans_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @plan.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /plans/1
  # DELETE /plans/1.xml
  def destroy
    @plan = object

    if @plan.contracts.count > 0
      flash[:notice] = t 'messages.plan.could_not_be_deleted', :count => @plan.contracts.count
      redirect_to :back
    else
      @plan.destroy
      redirect_back_from_edit_or_to plans_url
    end
  end
  private
  def object
    @object ||= Plan.find(params[:id])
  end
end
