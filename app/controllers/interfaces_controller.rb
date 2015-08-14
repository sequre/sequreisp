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

class InterfacesController < ApplicationController
  before_filter :require_user
  permissions :interfaces

  # GET /interfaces
  # GET /interfaces.xml
  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Interface.search(params[:search])
    @interfaces = @search.paginate(:page => params[:page],:per_page => 30)
    @graphs = @interfaces.map{ |i| InterfaceGraph.new(i, "interface_instant") }

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @interfaces }
    end
  end

  # GET /interfaces/1
  # GET /interfaces/1.xml
  def show
    @interface = object
    @periods = InterfaceSample::CONF_PERIODS.size
    @graphs = {}

    InterfaceGraph.supported_graph(@interface).each do |graph_name|
      @graphs[graph_name] = InterfaceGraph.new(@interface, graph_name)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @interface }
    end
  end

  # GET /interfaces/new
  # GET /interfaces/new.xml
  def new
    @interface = Interface.new
    @interface.addresses.build
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @interface }
    end
  end

  # GET /interfaces/1/edit
  def edit
    @interface = object
  end

  # POST /interfaces
  # POST /interfaces.xml
  def create
    @interface = Interface.new(params[:interface])

    respond_to do |format|
      if @interface.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(interfaces_path) }
        format.xml  { render :xml => @interface, :status => :created, :location => @interface }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @interface.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /interfaces/1
  # PUT /interfaces/1.xml
  def update
    @interface = object

    respond_to do |format|
      if @interface.update_attributes(params[:interface])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(interfaces_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @interface.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /interfaces/1
  # DELETE /interfaces/1.xml
  def destroy
    @interface = object
    if @interface.vlan_interfaces.size > 0
      flash[:error] = t 'messages.interface.could_not_be_deleted_has_vlans'
      redirect_to :back
    elsif @interface.provider
      flash[:error] = t 'messages.interface.could_not_be_deleted_has_provider'
      redirect_to :back
    elsif @interface.contracts.size > 0
      flash[:error] = t 'messages.interface.could_not_be_deleted_has_proxy_arp_contracts'
      redirect_to :back
    elsif @interface.iproutes.size > 0
      flash[:error] = t 'messages.interface.could_not_be_deleted_with_associated_iproutes'
      redirect_to :back
    else
      @interface.destroy
      redirect_back_from_edit_or_to interfaces_url
    end
  end
  def instant
    @interface = object
    respond_to do |format|
      format.json { render :json => @interface.instant }
    end
  end
  def scan
    count=0
    Interface.scan.each do |name|
      unless Interface.find_by_name(name)
        Interface.create :name => name, :kind => 'wan', :vlan => false
        count+=1
      end
    end
    if count > 0
      flash[:notice] = I18n.t('messages.interface.scan_success')
    else
      flash[:warning] = I18n.t('messages.interface.scan_fail')
    end
    redirect_to :back
  end
  def graph
    @interface = object
    @graph = Graph.new(:class => object.class.name, :id => object.id)
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @graph }
    end
  end

  def get_mac_address
    mac_address = params[:name].nil? ? nil : Interface.which_is_real_mac_address(params[:name])
    mac_address = Interface.new(:vlan_id => params[:id_vlan]).generate_internal_mac_address unless params[:id_vlan].blank?

    if_contract_exists = false
    if_interface_exists = false

    if mac_address
      if_contract_exists = Contract.all(:conditions => ["mac_address = ?", mac_address ]).first.try(:id) || false
      if_interface_exists = Interface.only_lan.all(:conditions => ["mac_address = ? AND id <> ?", mac_address, params[:interface_id] ]).first.try(:id) || false
    end

    respond_to do |format|
      format.json { render :json => {:mac_address => mac_address , :contract_exists => if_contract_exists, :interface_exists => if_interface_exists} }
    end
  end

  private
  def object
    @object ||= Interface.find(params[:id])
  end
end
