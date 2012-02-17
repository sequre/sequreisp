class DashboardsController < ApplicationController
  before_filter :require_user
  permissions :dashboard
  def show
    @disks = Dashboard::Disk.load_all
    @ram = Dashboard::Memory.new(/Mem:/)
    @swap = Dashboard::Memory.new(/Swap:/)
    @services = Dashboard::Service.load_all
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
  def load_average
    @load_average = Dashboard::LoadAverage.new
    respond_to do |format|
      format.json { render :json => @load_average }
    end 
  end
end
