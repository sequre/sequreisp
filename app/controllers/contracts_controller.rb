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

class ContractsController < ApplicationController
  before_filter :require_user
  permissions :contracts
  # GET /contracts
  # GET /contracts.xml
  def index
    params[:search] ||= {}
    # delete proxy_arp boolean condition unless it is true
    # that results in a more intuitive behavior
    params[:search].delete("proxy_arp_is") if params[:search]["proxy_arp_is"] == "0"
    params[:search][:order] ||= 'ascend_by_ip_custom'
    @search = Contract.search(params[:search])
    @contracts = @search.paginate(:page => params[:page],:per_page => 10)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @contracts }
      format.csv do
          # header row
        @contracts = Contract.search(params[:search])
        csv_string = FasterCSV.generate(:col_sep => ";") do |csv|
          csv << [
            t('activerecord.models.contract.one') + " " + t('activerecord.attributes.contract.id'),
            t('activerecord.attributes.contract.created_at'),
            t('activerecord.attributes.contract.client'),
            t('activerecord.models.client.one') + " " + t('activerecord.attributes.client.id'),
            t('activerecord.attributes.client.external_client_number'),
            t('activerecord.attributes.client.email'),
            t('activerecord.attributes.client.address'),
            t('activerecord.attributes.client.phone'),
            t('activerecord.attributes.client.phone_mobile'),
            t('activerecord.attributes.client.details'),
            t('activerecord.attributes.contract.plan'),
            t('activerecord.models.provider_group.one'),
            t('activerecord.attributes.plan.rate_down'),
            t('activerecord.attributes.plan.ceil_down'),
            t('activerecord.attributes.plan.rate_up'),
            t('activerecord.attributes.plan.ceil_up'),
            t('activerecord.attributes.contract.ip'),
            #t('activerecord.attributes.contract.forwarded_ports'),
            t('activerecord.attributes.contract.state')
          ]
  
          # data rows
          @contracts.each do |c|
            csv << [
              c.id,
              l(c.created_at.to_date),
              c.client.name,
              c.client.id,
              c.client.external_client_number,
              c.client.email,
              c.client.address,
              c.client.phone,
              c.client.phone_mobile,
              c.client.details,
              c.plan.name,
              c.plan.provider_group.name,
              c.plan.rate_down,
              c.plan.ceil_down,
              c.plan.rate_up,
              c.plan.ceil_up,
              c.ip,
              #c.forwarded_ports.collect{ |fp| "[#{fp.provider.name}]#{fp.public_port}=>#{fp.private_port}" }.join("|"),
              c.state 
            ]
          end
        end
        # send it to the browsah
        send_data csv_string,
                :type => 'text/csv; charset=UTF-8; header=present',
                :disposition => "attachment; filename=sequreisp_contracts_#{Time.now.strftime("%Y-%m-%d")}.csv"
      end
    end
  end

  # GET /contracts/1
  # GET /contracts/1.xml
  def show
    @contract = object
    render :action => "edit"
  end

  # GET /contracts/new
  # GET /contracts/new.xml
  def new
    @contract = Contract.new
    @contract.client_id = params[:client_id] unless params[:client_id].nil?
    @contract.ceil_dfl_percent = 70

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @contract }
    end
  end

  # GET /contracts/1/edit
  def edit
    @contract = object
  end

  # POST /contracts
  # POST /contracts.xml
  def create
    @contract = Contract.new(params[:contract])

    respond_to do |format|
      if @contract.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(contracts_path) }
        format.xml  { render :xml => @contract, :status => :created, :location => @contract }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /contracts/1
  # PUT /contracts/1.xml
  def update
    @contract = object

    respond_to do |format|
      if @contract.update_attributes(params[:contract])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(contracts_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /contracts/1
  # DELETE /contracts/1.xml
  def destroy
    @contract = object
    @contract.destroy

    respond_to do |format|
      format.html { redirect_to(contracts_url) }
      format.xml  { head :ok }
    end
  end
  def instant_rate
    @contract = object
    respond_to do |format|
      format.json { render :json => { :down => @contract.instant_rate_down, :up => @contract.instant_rate_up } }
    end 
  end

  def free_ips
    respond_to do |format|
      format.json { render :json => Contract.free_ips(params[:term])[0..9] }
    end
  end
  def ips
    respond_to do |format|
      format.json { render :json => Contract.all(:conditions => ["ip like ?", "%#{params[:term]}%"], :limit => 10, :select => :ip).collect(&:ip) }
    end
  end
  def arping_mac_address
    # arping will be excecuted by sudo, let's enshure that only an ip address is submited
    c = Contract.new(:ip => params[:ip])
    mac_address = (IP.new(params[:ip]) rescue nil).nil? ? nil : c.arping_mac_address
    respond_to do |format|
      format.json { render :json => {:mac_address => mac_address} }
    end
  end
  private
  def object
    @object ||= Contract.find(params[:id])
  end
end
