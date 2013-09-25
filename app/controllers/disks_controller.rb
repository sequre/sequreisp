class DisksController < ApplicationController

  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Disk.search(params[:search])
    @disks = @search.paginate(:page => params[:page],:per_page => 10)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def edit   
    @disk = Disk.find(params[:id])
  end

  def update
    @disk = Disk.find(params[:id])
      respond_to do |format|
      if @disk.update_attributes(params[:disk])
    format.html { redirect_to disks_path }
      else
        format.html { render :action => "edit" }  
      end
    end
  end
end
