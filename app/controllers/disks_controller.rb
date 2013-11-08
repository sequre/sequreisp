class DisksController < ApplicationController
  before_filter :require_user
  permissions :disks

  def index
    @free_disks = Disk.free
    @system_disks = Disk.find(:all, :conditions => {:system => true, :free => false})
    @cache_disks = Disk.find(:all, :conditions => {:cache => true, :free => false})
    hook_other_uses
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @disks}
    end
  end

  def liberate
    if params[:liberate_disks_ids].present?
      count = 0
      Disk.find(params[:liberate_disks_ids]).each do |disk|
        disk.assigned_for([:free])
        count += 1
      end
      if count > 0
        flash[:notice] = I18n.t('messages.disk.liberate')
      else
        flash[:warning] = I18n.t('messages.disk.not_liberate')
      end
    else
      flash[:warning] = I18n.t('messages.disk.empty_selection')
    end
    redirect_to disks_path
  end

  def assign_for
    if params[:assign_disks_ids].present?
      if params[:cache].present?
        assign_for_cache
      else
        hook_assign_for
      end
    else
      flash[:warning] = I18n.t('messages.disk.empty_selection')
      redirect_to disks_path
    end
  end

  def scan
    count = 0

    Disk.destroy_all

    Disk.scan.each_value do |disk|
      count += 1
      Disk.create(disk)
    end

    if count > 0
      flash[:notice] = I18n.t('messages.disk.scan_success')
    else
      flash[:warning] = I18n.t('messages.disk.scan_fail')
    end

    redirect_to disks_path
  end

  private

  def assign_for_cache
    count = 0
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.prepare_disk_for = "cache"
      disk.save
      count += 1
    end
    if count > 0
      flash[:notice] = I18n.t('messages.disk.assign_for_cache')
    else
      flash[:warning] = I18n.t('messages.disk.not_assign_for_cache')
    end
    redirect_to disks_path
  end

  def hook_assign_for
  end

  def hook_other_uses
  end

end
