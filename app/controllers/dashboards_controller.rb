class DashboardsController < ApplicationController
  before_filter :require_user
  permissions :dashboard
  def show
    @services = load_services
    @daemons = Dashboard::Daemon.load_all
    @graphs_instant = {}
    @graphs = {}
    conf = Configuration.first
    SystemGraph.supported_graphs.each do |graph_name|
      if graph_name.include?("instant")
        @graphs_instant[graph_name] = SystemGraph.new(conf, graph_name)
      else
        @graphs[graph_name] = SystemGraph.new(conf, graph_name)
      end
    end

    @graphs.sort_by_key
    @graphs_instant.sort_by_key

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => conf }
    end
  end

  def instant
    system_information = Configuration.system_information
    @services = load_services
    system_information[:services] = render_to_string :partial => "services_rows", :layout => false
    respond_to do |format|
      format.json { render :json => system_information }
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

  private

  def load_services
    MoolService.all(Dashboard::SERVICES)
  end
end
