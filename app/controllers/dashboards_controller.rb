class DashboardsController < ApplicationController
  before_filter :require_user
  permissions :dashboard
  def show
    @disks = Dashboard::Disk.load_all
    @ram = Dashboard::Memory.new(/Mem:/)
    @swap = Dashboard::Memory.new(/Swap:/)
    @services = Dashboard::Service.load_all
    @daemons = Dashboard::Daemon.load_all
    @uptime = Dashboard::LoadAverage.uptime
  end
  def cpu
    @cpu = Dashboard::Cpu.new
    respond_to do |format|
      format.json { render :json => @cpu.stats }
    end
  end
  def services
    @services = Dashboard::Service.load_all
    respond_to do |format|
      format.json { render :json => @services }
    end
  end

  def daemons
    @daemons = Dashboard::Daemon.load_all
    respond_to do |format|
      format.json { render :json => @daemons }
    end
  end

  def load_average
    @load_average = Dashboard::LoadAverage.new
    respond_to do |format|
      format.json { render :json => @load_average }
    end
  end
  def reboot
    if system("sleep 5 && sudo /usr/sbin/reboot &")
      flash[:notice] = I18n.t('messages.dashboard.reboot')
    else
      flash[:error] = I18n.t('messages.dashboard.reboot_error')
    end
    redirect_to :back
  end
  def halt
    if system("sleep 5 && sudo /usr/sbin/halt &")
      flash[:notice] = I17n.t('messages.dashboard.halt')
    else
      flash[:error] = I18n.t('messages.dashboard.halt_error')
    end
    redirect_to :back
  end
end
