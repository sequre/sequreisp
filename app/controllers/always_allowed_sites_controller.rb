class AlwaysAllowedSitesController < ApplicationController
  before_filter :require_user
  permissions :always_allowed_sites

  def index
    @allowed_sites = AlwaysAllowedSite.paginate(:page => params[:page], :per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @allowed_sites }
    end
  end

  def new
    @always_allowed_site = AlwaysAllowedSite.new
  end

  def create
    @always_allowed_site = AlwaysAllowedSite.new(params[:always_allowed_site])
    respond_to do |format|
      if @always_allowed_site.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(always_allowed_sites_path) }
        format.xml { render :xml => @always_allowed_site, :status => :created, :location => @always_allowed_site}
      else
        flash[:error] = t 'controllers.unsuccessfully_created'
        format.html { render :action => "new" }
        format.xml  { render :xml => @always_allowed_site.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
    @always_allowed_site = object
  end

  def update
    @always_allowed_site = object

    respond_to do |format|
      if @always_allowed_site.update_attributes(params[:always_allowed_site])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(always_allowed_site_path) }
        format.xml  { head :ok }
      else
        flash[:error] = t 'controllers.unsuccessfully_updated'
        format.html { render :action => "edit" }
        format.xml  { render :xml => @always_allowed_site.errors, :status => :unprocessable_entity }
      end
    end
  end

    def destroy
    @always_allowed_site = object
    @always_allowed_site.destroy

    respond_to do |format|
      format.html { redirect_back_from_edit_or_to(always_allowed_sites_path) }
      format.xml  { head :ok }
    end
  end

  private

  def object
    @object ||= AlwaysAllowedSite.find(params[:id])
  end
end
