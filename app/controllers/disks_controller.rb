class DisksController < ApplicationController
  before_filter :require_user
  permissions :disks

  def index
    @free_disks = Disk.free
    @assigned_disks = Disk.assigned

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
        disk.save
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
    flashes = []
    result = Disk.scan

    flashes << I18n.t('messages.disk.new_disks_detected', :disk_count => result[:new_disks]) if result[:new_disks] > 0
    flashes << I18n.t('messages.disk.changed_in_disks_detected', :disk_count => result[:changed_disks]) if result[:changed_disks] > 0
    flashes << I18n.t('messages.disk.deleted_disks_detected', :disk_count => result[:deleted_disks]) if result[:deleted_disks] > 0

    flashes.present? ? flash[:notice] = flashes.join("  ") : flash[:warning] = I18n.t('messages.disk.scan_fail')

    redirect_to disks_path
  end

  private

  def assign_for_cache
    count = 0
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.prepare_disk_for_cache = true
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

end
