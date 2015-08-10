# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

class Graph
  # require 'sequreisp_logger'
  # RRD_DB_DIR=RAILS_ROOT + "/db/rrd"
  # RRD_IMG_DIR=RAILS_ROOT + "/public/images/rrd"
  # def initialize(options)
  #   @element = nil
  #   if options[:element].nil?
  #     if (not options[:class].nil?) and (not options[:id].nil?)
  #       @element = options[:class].constantize.find options[:id]
  #     end
  #   else
  #     @element = options[:element]
  #   end
  #   raise "Undefined :element or :class,:id" if @element.nil?
  # end

  GREEN = '#00aa00'
  RED = '#aa0000'

  attr_accessor :model, :method, :render

  def initialize(model, method, options={})
    @model = model
    @method = method
    @render = "#{@method}_#{@model.id}"
    @minimal = false
  end

  def graph!; send(@method).to_json; end

  def minimal_graph
    @minimal = true
    _graph = graph!
    @minimal = false
    _graph
  end

  def name; @model.class.name; end

  def self.all_graphs(model)
    model_graph = "#{model.class.name}Graph".constantize
    model_graph::GRAPHS.map{|g| model_graph.new(model, g)}
  end

  def path
    # eval("app.graph_#{@model.class.name.downcase}_path(#{@model.id})") # ESTE SIRVE PARA CUANDO LO EJECUTO DESDE CONSOLA
    "graph_#{@model.class.name.downcase}_path(#{@model.id})"
  end

  private

  def default_options_graphs options={}
    options[:type] ||= 'line'
    options[:xtype] ||= 'datetime'
    options[:legend] = true unless options.has_key?(:legend)

    { :credits     => { :enabled => false },
      :chart       => { :renderTo => @render, :zoomType => 'x' },
      :exporting   => { :enabled => true },
      :legend      => { :enabled => options[:legend], :verticalAlign => 'bottom' },
      :title       => { :text => @minimal? '' : options[:title] },
      :xAxis       => { :type => options[:xtype] },
      :yAxis       => { :title => { :text => @minimal? '' : options[:ytitle] } },
      :plotOptions => { options[:type].to_sym => { :stacking => options[:stacking] } },
      :series      => options[:series] }
  end

  def faker_values hash=nil
    hash ||= { :keys => {}, :size => 0 }
    fake = {}
    date_time_now = (DateTime.now.to_i + Time.now.utc_offset) * 1000

    hash[:keys].each do |key, value|
      fake[key] = []
      hash[:size].times do |i|
        date = date_time_now - (i * 1000)
        fake[key] << [ date, value.zero? ? 0 : rand(value) ]
      end
    end

    fake
  end


  # def interface_rate_graph(@model)
  #   render_to = "interface_#{@model.id}_rate"
  #   speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
  #   data = {:tx => [], :rx => []}

  #   date_keys = $redis.keys("interface_#{@model.id}_sample_*").sort
  #   data = faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: speed * 0.99, :tx => Rails.env.production? ? 0 : speed * 0.99}}) if date_keys.empty?

  #   InterfaceSample.compact_keys.each do |rkey|
  #     date_keys.each do |key|
  #       time = $redis.hget("#{key}", "time").to_i * 1000
  #       value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
  #       data[rkey[:name].to_sym] << [ time, value ]
  #     end
  #   end

  #   series = []
  #   series << { :name => "rx", :type=> "spline", :color=> GREEN, :marker => { :enabled=> false }, :stack => "rx", :data => data[:rx].sort }
  #   series << { :name => "tx", :type=> "spline", :color=> RED,   :marker => { :enabled=> false }, :stack => "tx", :data => data[:tx].sort }

  #   graph = { :title =>'',
  #             :render_to => render_to,
  #             :ytitle => '',
  #             :legend => false,
  #             :series => series }

  #   { render_to => default_options_graphs(graph) }
  # end

  # def interface_rate_graph_for_periods(@model)
  #   speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
  #   graphs = {}
  #   samples_by_period = InterfaceSample.all(:conditions => { :interface_id => @model.id} ).group_by(&:period)
  #   samples_by_period.each do |period, samples|
  #     data = {}
  #     if Rails.env.production?
  #       InterfaceSample.compact_keys.each do |rkey|
  #         data[rkey[:name]] = []
  #         samples.each do |sample|
  #           data[rkey[:name]] << [ (sample.sample_number.to_i * 1000), sample[rkey[:name].to_sym] ]
  #         end
  #       end
  #     else
  #       hash = {:size => InterfaceSample::CONF_PERIODS[period.to_sym][:sample_size], :keys => {}}
  #       InterfaceSample.compact_keys.each { |rkey| hash[:keys][:name] = speed * 0.99 }
  #       data = faker_values(hash)
  #     end

  #     graph = { :title => I18n.t("graphs.titles.instant_period_#{period}"),
  #               :type => 'areaspline',
  #               :render_to => "contract_rate_period_#{period}",
  #               :stacking => 'normal',
  #               :ytitle => 'bps(bits/second)',
  #               :series => [] }

  #     data.each do |key, value|
  #       graph[:series] << { :name => key, :type=> "areaspline", :stack => "rx", :data => value } if key.include? "rx"
  #       graph[:series] << { :name => key, :type=> "areaspline", :stack => "tx", :data => value } if key.include? "tx"
  #     end

  #     graphs["interface_#{@model.id}_rate_period_#{period}"] = default_options_graphs(graph)
  #   end
  #   graphs
  # end

  # def provider_group_rate_graph(@model)
  #   render_to = "provider_group_#{@model.id}_rate"
  #   interfaces = @model.providers.map{ |p| p.interface }
  #   datas = []

  #   datas << faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: 100 * 0.99, :tx => Rails.env.production? ? 0 : 100 * 0.99}}) if interfaces.empty?

  #   interfaces.each do |i|
  #     speed = i.speed.map {|x| x[/\d+/]}.first.to_i
  #     data = {:tx => [], :rx => []}
  #     date_keys = $redis.keys("interface_#{i.id}_sample_*").sort
  #     data = faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: speed * 0.99, :tx => Rails.env.production? ? 0 : speed * 0.99}}) if date_keys.empty?

  #     date_keys.each do |key|
  #       time = $redis.hget("#{key}", "time").to_i* 1000
  #       value_up = 0
  #       value_down = 0
  #       rkey_down.each do |rkey|
  #         value_rx += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
  #       end
  #       rkey_up.each do |rkey|
  #         value_tx += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
  #       end
  #       data[:rx] << [time, value_rx]
  #       data[:tx] << [time, value_tx]
  #     end
  #     datas << data
  #   end

  #   series = []

  #   unless datas.empty?
  #     datas = datas.sum
  #     series << { :name => "rx", :type=> "spline", :color=> GREEN, :marker => { :enabled=> false }, :stack => "rx", :data => datas[:rx].sort }
  #     series << { :name => "tx", :type=> "spline", :color=> RED,   :marker => { :enabled=> false }, :stack => "tx", :data => datas[:tx].sort }
  #   end

  #   graph = { :title =>'',
  #             :render_to => render_to,
  #             :ytitle => '',
  #             :legend => false,
  #             :series => series }

  #   { render_to => default_options_graphs(graph) }
  # end












































  # def instant_rate_path
  #   case @graph.element.class.to_s
  #   when "Contract"
  #     instant_rate_contract_path(@graph.element)
  #   when "Provider"
  #     instant_rate_interface_path(@graph.element.interface)
  #   when "ProviderGroup"
  #     instant_rate_provider_group_path(@graph.element)
  #   when "Interface"
  #     instant_rate_interface_path(@graph.element)
  #   end
  # end

  # def name
  #   case element.class.to_s
  #   when "Contract"
  #     "#{element.client.name}"
  #   when "Provider", "ProviderGroup", "Interface"
  #     "#{element.name}"
  #   end
  # end
  # def img(mtime, msize)
  #   width = 0
  #   height = 0
  #   time = 0
  #   xgrid = 0
  #   case mtime
  #   when "hour"
  #     time = "-1h"
  #     xgrid = "MINUTE:10:MINUTE:30:MINUTE:30:0:\%H:\%M"
  #   when "day"
  #     time = "-1d"
  #     xgrid = "MINUTE:30:HOUR:1:HOUR:3:0:\%H:\%M"
  #   when "week"
  #     time = "-7d"
  #     xgrid = "HOUR:6:DAY:1:DAY:1:0:\%a-\%d"
  #   when "month"
  #     time = "-1m"
  #     xgrid = "DAY:1:DAY:7:DAY:7:0:\%d-\%b"
  #   when "year"
  #     time = "-1y"
  #     xgrid = "MONTH:1:MONTH:1:MONTH:1:0:\%b"
  #   end
  #   case msize
  #   when "small"
  #     width = 150
  #     height = 62
  #     xgrid = "HOUR:6:HOUR:6:HOUR:6:0:\%Hhs"
  #     graph_small(time, xgrid, width, height)
  #   when "medium"
  #     width = 500
  #     height = 60
  #     graph(time, xgrid, width, height)
  #   when "large"
  #     width = 650
  #     height = 180
  #     graph(time, xgrid, width, height)
  #   end
  # end
  # def path_rrd
  #   RRD_DB_DIR + "/#{element.class.to_s}.#{element.id}.rrd"
  # end
  # def path_img(gname)
  #   RRD_IMG_DIR + "/#{gname}.png"
  # end
  # def rrd_graph(args=[])
  #   begin
  #     eval "RRD::Wrapper.graph!(" + args.collect{ |n| "'" + n +  "'" }.join(",") + ")"
  #   rescue => e
  #     log_rescue("[Model][Graph][rrd_graph]", e)
  #     Rails.logger.error "ERROR: Graph::grpah #{e.inspect}"
  #     nil
  #   end
  # end
  # def rrd_args_for_element
  #   case element.class.to_s
  #   when "Interface"
  #     [
  #       "AREA:down_prio_#00AA00:down",
  #       "LINE1:up_prio_#FF0000:up",
  #       "HRULE:#{element.rate_down*1024}#00AA0066",
  #       "HRULE:#{element.rate_up*1024}#FF000066",
  #       "--upper-limit=#{element.rate_down*1000}",
  #     ]
  #   when "Provider", "ProviderGroup"
  #     args = [ "AREA:down_prio_#00AA00:down" ]
  #     args += [ "LINE1:up_prio_#FF0000:up" ]
  #     args +=
  #     [
  #       "HRULE:#{element.rate_down*1024}#00AA0066",
  #       "HRULE:#{element.rate_up*1024}#FF000066",
  #       "--upper-limit=#{element.rate_down*1000}",
  #     ]
  #   when "Contract"
  #     [
  #       "AREA:down_prio_#00AA00:down",
  #       "STACK:down_dfl_#00EE00:down p2p",
  #       "LINE1:up_prio_#FF0000:up",
  #       "STACK:up_dfl_#FF6600:up p2p",
  #       "HRULE:#{element.plan.ceil_down*1024}#00AA0066",
  #       "HRULE:#{element.plan.ceil_up*1024}#FF000066",
  #       "--upper-limit=#{element.plan.ceil_down*1000}",
  #     ]
  #   end
  # end
  # def rrd_default_args(gname, time, xgrid, width, height)
  #   [
  #     path_img(gname),
  #     "-s", time,
  #     "DEF:down_prio=#{path_rrd}:down_prio:AVERAGE",
  #     "DEF:down_dfl=#{path_rrd}:down_dfl:AVERAGE",
  #     "DEF:up_prio=#{path_rrd}:up_prio:AVERAGE",
  #     "DEF:up_dfl=#{path_rrd}:up_dfl:AVERAGE",
  #     "CDEF:down_prio_=down_prio,8,*",
  #     "CDEF:down_dfl_=down_dfl,8,*",
  #     "CDEF:down_=down_prio_,down_dfl_,+",
  #     "CDEF:up_prio_=up_prio,8,*",
  #     "CDEF:up_dfl_=up_dfl,8,*",
  #     "--interlaced",
  #     "--watermark=Wispro",
  #     "--lower-limit=0",
  #     "--x-grid", xgrid,
  #     "--alt-y-grid",
  #     "--width", "#{width}",
  #     "--height", "#{height}",
  #     "--imgformat", "PNG"
  #   ]
  # end
  # def graph(time, xgrid, width, height)
  #   gname = "#{element.class.to_s}.#{element.id}.#{time}.#{width}.#{height}"
  #   rrd_args = rrd_default_args(gname, time, xgrid, width, height) + rrd_args_for_element
  #   alt = "No disponible" unless rrd_graph(rrd_args)
  #   "<img alt=\"#{alt}\" src=\"/images/rrd/#{gname}.png\">"
  #   #"<a href=\"/graphs/#{element.id}/?class=#{element.class.to_s}\"><img src=\"/images/rrd/#{gname}.png\"></a>"
  # end
  # def graph_small(time, xgrid, width, height)
  #   gname = "#{element.class.to_s}.#{element.id}.#{time}.#{width}.#{height}"
  #   rrd_args = rrd_default_args(gname, time, xgrid, width, height) + [ "--no-legend" ] + rrd_args_for_element
  #   alt = "No disponible" unless rrd_graph(rrd_args)
  #   "<img alt=\"#{alt}\" src=\"/images/rrd/#{gname}.png\">"
  # end
end
