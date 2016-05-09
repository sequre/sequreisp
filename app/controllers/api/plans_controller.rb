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

class Api::PlansController < Api::ApiController
  permissions :plans
  # GET /plans
  # GET /plans.xml
  def index
    params[:search] ||= {}
    @plans = Plan.search(params[:search]).all

    respond_to do |format|
      format.json  { render :json => @plans }
    end
  end

  # GET /plans/1
  # GET /plans/1.xml
  def show
    @plan = object
    respond_to do |format|
      format.json  { render :json => @plan }
    end
  end

  # GET /plans/new
  # GET /plans/new.xml
  def new
    @plan = Plan.new

    respond_to do |format|
      format.json  { render :json => @plan }
    end
  end

  # GET /plans/1/edit
  def edit
    @plan = object
    respond_to do |format|
      format.json  { render :json => @plan }
    end
  end

  # POST /plans
  # POST /plans.xml
  def create
    @plan = Plan.new(params[:plan])

    respond_to do |format|
      if @plan.save
        format.json  { render :json => @plan, :status => :created, :location => @plan }
      else
        format.json  { render :json => @plan.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /plans/1
  # PUT /plans/1.xml
  def update
    @plan = object
    respond_to do |format|
      if @plan.update_attributes(params[:plan])
        format.json  { head :ok }
      else
        format.json  { render :json => @plan.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /plans/1
  # DELETE /plans/1.xml
  def destroy
    @plan = object
    @plan.destroy

    respond_to do |format|
      format.json  { head :ok }
    end
  end
  private
  def object
    @object ||= Plan.find(params[:id])
  end
end
