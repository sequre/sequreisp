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

  def free_assign_for
    flashes = {:error => [], :notice => [], :warning => [] }
    if params[:assign_disks_ids].present?
      if params[:liberate].present?
        free_assign_for_liberate(flashes)
      elsif params[:cache].present?
        free_assign_for_cache(flashes)
      else
        hook_free_assign_for(flashes)
      end
    else
      flashes[:warning] << I18n.t('messages.disk.empty_selection')
    end
    flash[:notice] = flashes[:notice].join(" ") if flashes[:notice].present?
    flash[:warning] = flashes[:warning].join(" ") if flashes[:warning].present?
    flash[:error] = flashes[:error].join(" ") if flashes[:error].present?
    redirect_to disks_path
  end

  def assigned_assign_for
    flashes = {:error => [], :notice => [], :warning => [] }

    if params[:assigned_disks_ids].present?
      if params[:liberate].present?
        assigned_assign_for_liberate(flashes)
      end
      if params[:clean].present?
        assigned_assign_for_clean_cache(flashes)
      end
    else
      flashes[:warning] << I18n.t('messages.disk.empty_selection')
    end
    flash[:notice] = flashes[:notice].join(" ") if flashes[:notice].present?
    flash[:warning] = flashes[:warning].join(" ") if flashes[:warning].present?
    flash[:error] = flashes[:error].join(" ") if flashes[:error].present?

    redirect_to disks_path
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

  def free_assign_for_liberate(flashes)
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.prepare_disk_for_cache = false
      hook_free_assign_for_liberate(disk)
      if disk.changed?
        disk.save
        flashes[:notice] << "el disco #{disk.name} se ha liberado"
      else
        flashes[:warning] << "el disco #{disk.name} ya esta liberado"
      end
    end
  end

  def free_assign_for_cache(flashes)
    Disk.find(params[:assign_disks_ids]).each do |disk|
      disk.prepare_disk_for_cache = true
      if disk.changed?
        disk.save
        flashes[:notice] << "el disco #{disk.name} se ha asignado a cache"
      else
        flashes[:warning] << "el disco #{disk.name} ya esta asignado a cache"
      end
    end
  end

  def hook_free_assign_for(flashes)
  end

  def hook_free_assign_for_liberate(disk)
  end

  def assigned_assign_for_liberate(flashes)
    count = 0
    Disk.find(params[:assigned_disks_ids]).each do |disk|
      disk.assigned_for([:free])
      disk.save
      count += 1
    end
    if count > 0
      flashes[:notice] << I18n.t('messages.disk.liberate')
    else
      flashes[:warning] << I18n.t('messages.disk.not_liberate')
    end
  end

  def assigned_assign_for_clean_cache(flashes)
    Disk.find(params[:assigned_disks_ids]).each do |disk|
      if not disk.system?
        disk.prepare_disk_for_cache = true if disk.cache?
        hook_assigned_assign_for_clean_cache(disk)
        disk.save
        flashes[:notice] << "Se limpiara el cache del disco #{disk.name}"
      else
        flashes[:error] << "No puede borrarse el cache del disco #{disk.name}"
      end
    end
  end

  def hook_assigned_assign_for_clean_cache(disk)
  end

end
