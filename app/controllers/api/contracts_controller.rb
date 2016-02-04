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

class Api::ContractsController < ApplicationController
  # GET /contracts
  # GET /contracts.xml
  def index
    params[:search] ||= {}
    @contracts = Contract.search(params[:search]).all

    respond_to do |format|
      format.json  { render :json => @contracts }
    end
  end

  # GET /contracts/1
  # GET /contracts/1.xml
  def show
    @contract = object
    respond_to do |format|
      format.json  { render :json => @contract }
    end
  end

  # GET /contracts/new
  # GET /contracts/new.xml
  def new
    @contract = Contract.new

    respond_to do |format|
      format.json  { render :json => @contract }
    end
  end

  # GET /contracts/1/edit
  def edit
    @contract = object
    respond_to do |format|
      format.json  { render :json => @contract }
    end
  end

  # POST /contracts
  # POST /contracts.xml
  def create
    @contract = Contract.new(params[:contract])

    respond_to do |format|
      if @contract.save
        format.json  { render :json => @contract, :status => :created, :location => @contract }
      else
        format.json  { render :json => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /contracts/1
  # PUT /contracts/1.xml
  def update
    @contract = object
    respond_to do |format|
      if @contract.update_attributes(params[:contract])
        format.json  { head :ok }
      else
        format.json  { render :json => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /contracts/1
  # DELETE /contracts/1.xml
  def destroy
    @contract = object
    @contract.destroy

    respond_to do |format|
      format.json  { head :ok }
    end
  end
  private
  def object
    @object ||= Contract.find(params[:id])
  end
end
