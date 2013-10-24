class DisksController < ApplicationController

  def index
    @free_disks = Disk.free
    @system_disks = Disk.find(:all, :conditions => {:system => true})
    @cache_disks = Disk.find(:all, :conditions => {:cache => true, :videocache => false})
    hook_other_uses
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def liberate
    count = 0
    Disk.find(params[:liberate_disks_ids]).each do |disk|
      disk.assigned_for([:free])
      disk.save
      count += 1
    end
    if count > 0
      flash[:notice] = I18n.t('messages.disk.liberate')
    else
      flash[:warning] = I18n.t('messages.disk.not_liberate')
    end
    redirect_to disks_path
  end

  def assign_for
    if params[:cache].present?
      assign_for_cache
    else
      hook_assign_for
    end
  end

  def scan
    count_create = 0
    count_destroy = 0

    scan_disks = Disk.scan
    collect_disks = Disk.all.collect(&:serial)

    count_destroy = Disk.destroy_disks(collect_disks - scan_disks.map{|b| b[1][:serial]})
    count_create = Disk.create_or_change_disks(scan_disks)

    conf = Configuration.first
    conf.mount_cache = false
    conf.save

    if count_destroy > 0  or count_create > 0
      flash[:notice] = I18n.t('messages.disk.scan_success')
    else
      flash[:warning] = I18n.t('messages.disk.scan_fail')
    end
    redirect_to disks_path
  end

  private

  def hook_assign_for
  end

  def hook_other_uses
  end

  def assign_for_cache
    count = 0
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.assigned_for([:cache])
      count += 1
    end
    if count > 0
      flash[:notice] = I18n.t('messages.disk.assign_for_cache')
    else
      flash[:warning] = I18n.t('messages.disk.not_assign_for_cache')
    end
    redirect_to disks_path
  end

end
