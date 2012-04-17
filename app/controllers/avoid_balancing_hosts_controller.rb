class AvoidBalancingHostsController < ApplicationController
  before_filter :require_user
  permissions :avoid_balancing_hosts

  # GET /avoid_balancing_hosts
  # GET /avoid_balancing_hosts.xml
  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = AvoidBalancingHost.search(params[:search])
    @avoid_balancing_hosts = @search.paginate(:page => params[:page],:per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @avoid_balancing_hosts }
    end
  end

  # GET /avoid_balancing_hosts/1
  # GET /avoid_balancing_hosts/1.xml
  def show
    @avoid_balancing_host = object
    render :action => "edit"
  end

  # GET /avoid_balancing_hosts/new
  # GET /avoid_balancing_hosts/new.xml
  def new
    @avoid_balancing_host = AvoidBalancingHost.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @avoid_balancing_host }
    end
  end

  # GET /avoid_balancing_hosts/1/edit
  def edit
    @avoid_balancing_host = object
  end

  # POST /avoid_balancing_hosts
  # POST /avoid_balancing_hosts.xml
  def create
    @avoid_balancing_host = AvoidBalancingHost.new(params[:avoid_balancing_host])

    respond_to do |format|
      if @avoid_balancing_host.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(avoid_balancing_hosts_path) }
        format.xml  { render :xml => @avoid_balancing_host, :status => :created, :location => @avoid_balancing_host }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @avoid_balancing_host.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /avoid_balancing_hosts/1
  # PUT /avoid_balancing_hosts/1.xml
  def update
    @avoid_balancing_host = object

    respond_to do |format|
      if @avoid_balancing_host.update_attributes(params[:avoid_balancing_host])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(avoid_balancing_hosts_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @avoid_balancing_host.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /avoid_balancing_hosts/1
  # DELETE /avoid_balancing_hosts/1.xml
  def destroy
    @avoid_balancing_host = object
    @avoid_balancing_host.destroy
    redirect_to(avoid_balancing_hosts_url)
  end
  private
  def object
    @object ||= AvoidBalancingHost.find(params[:id])
  end
end
