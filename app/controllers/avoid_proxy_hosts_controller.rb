class AvoidProxyHostsController < ApplicationController
  before_filter :require_user
  permissions :avoid_proxy_hosts

  # GET /avoid_proxy_hosts
  # GET /avoid_proxy_hosts.xml
  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = AvoidProxyHost.search(params[:search])
    @avoid_proxy_hosts = @search.paginate(:page => params[:page],:per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @avoid_proxy_hosts }
    end
  end

  # GET /avoid_proxy_hosts/1
  # GET /avoid_proxy_hosts/1.xml
  def show
    @avoid_proxy_host = object
    render :action => "edit"
  end

  # GET /avoid_proxy_hosts/new
  # GET /avoid_proxy_hosts/new.xml
  def new
    @avoid_proxy_host = AvoidProxyHost.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @avoid_proxy_host }
    end
  end

  # GET /avoid_proxy_hosts/1/edit
  def edit
    @avoid_proxy_host = object
  end

  # POST /avoid_proxy_hosts
  # POST /avoid_proxy_hosts.xml
  def create
    @avoid_proxy_host = AvoidProxyHost.new(params[:avoid_proxy_host])

    respond_to do |format|
      if @avoid_proxy_host.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(avoid_proxy_hosts_path) }
        format.xml  { render :xml => @avoid_proxy_host, :status => :created, :location => @avoid_proxy_host }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @avoid_proxy_host.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /avoid_proxy_hosts/1
  # PUT /avoid_proxy_hosts/1.xml
  def update
    @avoid_proxy_host = object

    respond_to do |format|
      if @avoid_proxy_host.update_attributes(params[:avoid_proxy_host])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(avoid_proxy_hosts_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @avoid_proxy_host.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /avoid_proxy_hosts/1
  # DELETE /avoid_proxy_hosts/1.xml
  def destroy
    @avoid_proxy_host = object
    @avoid_proxy_host.destroy
    redirect_to(avoid_proxy_hosts_url)
  end
  private
  def object
    @object ||= AvoidProxyHost.find(params[:id])
  end
end
