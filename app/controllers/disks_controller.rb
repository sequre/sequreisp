class DisksController < ApplicationController

  def system
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Disk.system.search(params[:search])
    @disks = @search.paginate(:page => params[:page],:per_page => 10)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def cache
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Disk.cache.search(params[:search])
    @disks = @search.paginate(:page => params[:page],:per_page => 10)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def free
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = Disk.free.search(params[:search])
    @disks = @search.paginate(:page => params[:page],:per_page => 10)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def liberate
    count = 0
    Disk.find(params[:liberate_disks_ids]).each do |disk|
      disk.system = false
      disk.cache = false
      disk.free = false
      disk.save
      count += 1
    end
    if count > 0
      flash[:notice] = I18n.t('messages.disk.liberate')
    else
      flash[:warning] = I18n.t('messages.disk.not_liberate')
    end
    redirect_to :back
  end

  def assign_for_cache
    count = 0
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.system = false
      disk.cache = true
      disk.save
      count += 1
    end
    if count > 0
      flash[:notice] = I18n.t('messages.disk.assign_for_cache')
    else
      flash[:warning] = I18n.t('messages.disk.not_assign_for_cache')
    end
    redirect_to :back
  end

  def scan
    count_create = 0
    count_destroy = 0

    scan_disks = Disk.scan
    collect_disks = Disk.all.collect(&:serial)

    count_destroy = Disk.destroy_disks(collect_disks - scan_disks.map{|b| b[1][:serial]})
    count_create = Disk.create_or_change_disks(scan_disks)

    if count_destroy > 0  or count_create > 0
      flash[:notice] = I18n.t('messages.disk.scan_success')
    else
      flash[:warning] = I18n.t('messages.disk.scan_fail')
    end
    redirect_to :back
  end

end
