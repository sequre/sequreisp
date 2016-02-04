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

class Api::ClientsController < ApplicationController
  # GET /clients
  # GET /clients.xml
  def index
    params[:search] ||= {}
    @clients = Client.search(params[:search]).all

    respond_to do |format|
      format.json  { render :json => @clients }
    end
  end

  # GET /clients/1
  # GET /clients/1.xml
  def show
    @client = object
    respond_to do |format|
      format.json  { render :json => @client }
    end
  end

  # GET /clients/new
  # GET /clients/new.xml
  def new
    @client = Client.new

    respond_to do |format|
      format.json  { render :json => @client }
    end
  end

  # GET /clients/1/edit
  def edit
    @client = object
    respond_to do |format|
      format.json  { render :json => @client }
    end
  end

  # POST /clients
  # POST /clients.xml
  def create
    @client = Client.new(params[:client])

    respond_to do |format|
      if @client.save
        format.json  { render :json => @client, :status => :created, :location => @client }
      else
        format.json  { render :json => @client.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /clients/1
  # PUT /clients/1.xml
  def update
    @client = object
    respond_to do |format|
      if @client.update_attributes(params[:client])
        format.json  { head :ok }
      else
        format.json  { render :json => @client.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /clients/1
  # DELETE /clients/1.xml
  def destroy
    @client = object
    @client.destroy

    respond_to do |format|
      format.json  { head :ok }
    end
  end
  private
  def object
    @object ||= Client.find(params[:id])
  end
end
