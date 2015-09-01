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

module GraphsHelper
  GREEN = '#00aa00'
  RED = '#aa0000'

  def route_path(path)
    eval(path)
  end

  def instant_rate_path
    case @graph.element.class.to_s
    when "Contract"
      instant_rate_contract_path(@graph.element)
    when "Provider"
      instant_rate_interface_path(@graph.element.interface)
    when "ProviderGroup"
      instant_rate_provider_group_path(@graph.element)
    when "Interface"
      instant_rate_interface_path(@graph.element)
    end
  end



  def default_options_graphs options={}
    options[:type] ||= 'line'
    options[:xtype] ||= 'datetime'
    options[:legend] = true unless options.has_key?(:legend)

    { :credits     => { :enabled => false },
      :chart       => { :renderTo => options[:render_to], :zoomType => 'x' },
      :exporting   => { :enabled => true },
      :legend      => { :enabled => options[:legend], :verticalAlign => 'bottom' },
      :title       => { :text => options[:title] },
      :xAxis       => { :type => options[:xtype] },
      :yAxis       => { :title => { :text => options[:ytitle] } },
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

  def contract_rate_graph(obj)
    data = {}
    date_keys = $redis.keys("contract_#{obj.id}_sample_*").sort

    ContractSample.compact_keys.each do |rkey|
      data[rkey[:name]] = []
      if Rails.env.production?
        date_keys.each do |key|
          time = $redis.hget("#{key}", "time").to_i * 1000
          value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
          data[rkey[:name]] << [ time, value ]
        end
      else
        date_time_now = (DateTime.now.to_i + Time.now.utc_offset) * 1000
        12.times do |i|
          date = date_time_now - (i * 1000)
          value = plan.send("ceil_#{rkey[:up_or_down]}") * rand(0.99)
          data[rkey[:name]] << [ date, value ]
        end
      end
    end

    graph_down = { :title => I18n.t("graphs.titles.instant_rate_down"),
                   :type => 'areaspline',
                   :render_to => 'instant_down',
                   :stacking => 'normal',
                   :ytitle => 'bps(bits/second)',
                   :series => [] }

    graph_up = { :title => I18n.t("graphs.titles.instant_rate_up"),
                 :type => 'areaspline',
                 :render_to => 'instant_up',
                 :stacking => 'normal',
                 :ytitle => 'bps(bits/second)',
                 :series => [] }


    data.each do |key, value|
      graph_up[:series] << { :name => key, :type=> "areaspline",   :stack => "up"  , :data => value } if key.include? "up"
      graph_down[:series] << { :name => key, :type=> "areaspline", :stack => "down", :data => value } if key.include? "down"
    end

    { "instant_up" => default_options_graphs(graph_up),
      "instant_down" => default_options_graphs(graph_down) }
  end

  def contract_rate_graph_for_periods(obj)
    graphs = {}
    samples_by_period = ContractSample.all(:conditions => { :contract_id => obj.id} ).group_by(&:period)

    samples_by_period.each do |period, samples|
      data = {}
      ContractSample.compact_keys.each do |rkey|
        data[rkey[:name]] = []
        samples.each do |sample|
          value = rkey[:name].include?("up")? sample[rkey[:name].to_sym]*-1 : sample[rkey[:name].to_sym]
          # data[rkey[:name]] << [ (sample.sample_number.to_i), value ]
          data[rkey[:name]] << [ ((sample.sample_number.to_i + Time.now.utc_offset) * 1000), value ]
        end
      end

      graph = { :title => I18n.t("graphs.titles.instant_period_#{period}"),
                :type => 'areaspline',
                :render_to => "contract_rate_period_#{period}",
                :stacking => 'normal',
                :ytitle => 'bps(bits/second)',
                :series => [] }


      data.each do |key, value|
        graph[:series] << { :name => key, :type=> "areaspline",   :stack => "up"  , :data => value } if key.include? "up"
        graph[:series] << { :name => key, :type=> "areaspline", :stack => "down", :data => value } if key.include? "down"
      end
      graphs["contract_rate_period_#{period}"] = default_options_graphs(graph)
    end
    graphs
  end

  def contract_graph_data_count(obj)

    graph = { :title => I18n.t("graphs.titles.data_count"),
              :render_to => "contract_data_count",
              :ytitle => I18n.t('graph.data'),
              :xtype => 'category',
              :series => [ { :name => I18n.t('graph.traffic'),
                             :type => 'column',
                             :data => obj.data_count_for_last_year } ] }

    { "contract_data_count" => default_options_graphs(graph) }
  end

  def contract_graph_latency(obj)
    date_time_now = (DateTime.now.to_i + Time.now.utc_offset) * 1000
    data = []
    10.times do |i|
      data << [date_time_now - (i * 1000), 0]
    end

    graph = { :title => I18n.t("graphs.titles.latency"),
              :render_to => 'contract_latency',
              :ytitle => I18n.t('graph.data'),
              :series => [ { :name => 'ping',
                             :color => GREEN,
                             :type => 'spline',
                             :data => data.reverse },
                           { :name => 'arping',
                             :color => RED,
                             :type => 'spline',
                             :data => data.reverse } ] }

    { 'contract_latency' => default_options_graphs(graph) }
  end

  def contract_total_rate_graph(obj)
    render_to = "contract_#{obj.id}_up_down"
    plan = obj.plan
    data = {:up => [], :down => []}
    date_keys = $redis.keys("contract_#{obj.id}_sample_*")
    rkey_down = ContractSample.compact_keys.select{ |a| a[:up_or_down] == "down" }
    rkey_up   = ContractSample.compact_keys.select{ |a| a[:up_or_down] == "up" }

    data = faker_values({ :size => 12, :keys => { :up =>   Rails.env.production? ? 0 : plan.ceil_up, :down => Rails.env.production? ? 0 : plan.ceil_down } }) if date_keys.empty?

    date_keys.sort.each do |key|
      time = $redis.hget("#{key}", "time").to_i * 1000
      value_up = 0
      value_down = 0
      rkey_down.each do |rkey|
        value_down += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
      end
      rkey_up.each do |rkey|
        value_up += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
      end
      data[:down] << [time, value_down]
      data[:up] << [time, value_up]
    end

    series = []

    series << { :name => "up",   :type=> "spline", :color => RED,   :marker => { :enabled => false }, :stack => "up",   :data => data[:up]   }
    series << { :name => "down", :type=> "spline", :color => GREEN, :marker => { :enabled => false }, :stack => "down", :data => data[:down] }

    graph = { :title => '',
              :render_to => render_to,
              :ytitle => '',
              :legend => false,
              :series => series }


    { render_to => default_options_graphs(graph) }
  end

  def interface_rate_graph(obj)
    render_to = "interface_#{obj.id}_rate"
    speed = obj.speed.map {|x| x[/\d+/]}.first.to_i
    data = {:tx => [], :rx => []}

    date_keys = $redis.keys("interface_#{obj.id}_sample_*").sort
    data = faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: speed * 0.99, :tx => Rails.env.production? ? 0 : speed * 0.99}}) if date_keys.empty?

    InterfaceSample.compact_keys.each do |rkey|
      date_keys.each do |key|
        time = $redis.hget("#{key}", "time").to_i * 1000
        value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
        data[rkey[:name].to_sym] << [ time, value ]
      end
    end

    series = []
    series << { :name => "rx", :type=> "spline", :color=> GREEN, :marker => { :enabled=> false }, :stack => "rx", :data => data[:rx].sort }
    series << { :name => "tx", :type=> "spline", :color=> RED,   :marker => { :enabled=> false }, :stack => "tx", :data => data[:tx].sort }

    graph = { :title =>'',
              :render_to => render_to,
              :ytitle => '',
              :legend => false,
              :series => series }

    { render_to => default_options_graphs(graph) }
  end

  def interface_rate_graph_for_periods(obj)
    speed = obj.speed.map {|x| x[/\d+/]}.first.to_i
    graphs = {}
    samples_by_period = InterfaceSample.all(:conditions => { :interface_id => obj.id} ).group_by(&:period)
    samples_by_period.each do |period, samples|
      data = {}
      if Rails.env.production?
        InterfaceSample.compact_keys.each do |rkey|
          data[rkey[:name]] = []
          samples.each do |sample|
            data[rkey[:name]] << [ (sample.sample_number.to_i * 1000), sample[rkey[:name].to_sym] ]
          end
        end
      else
        hash = {:size => InterfaceSample::CONF_PERIODS[period.to_sym][:sample_size], :keys => {}}
        InterfaceSample.compact_keys.each { |rkey| hash[:keys][:name] = speed * 0.99 }
        data = faker_values(hash)
      end

      graph = { :title => I18n.t("graphs.titles.instant_period_#{period}"),
                :type => 'areaspline',
                :render_to => "contract_rate_period_#{period}",
                :stacking => 'normal',
                :ytitle => 'bps(bits/second)',
                :series => [] }

      data.each do |key, value|
        graph[:series] << { :name => key, :type=> "areaspline", :stack => "rx", :data => value } if key.include? "rx"
        graph[:series] << { :name => key, :type=> "areaspline", :stack => "tx", :data => value } if key.include? "tx"
      end

      graphs["interface_#{obj.id}_rate_period_#{period}"] = default_options_graphs(graph)
    end
    graphs
  end

  def provider_group_rate_graph(obj)
    render_to = "provider_group_#{obj.id}_rate"
    interfaces = obj.providers.map{ |p| p.interface }
    datas = []

    datas << faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: 100 * 0.99, :tx => Rails.env.production? ? 0 : 100 * 0.99}}) if interfaces.empty?

    interfaces.each do |i|
      speed = i.speed.map {|x| x[/\d+/]}.first.to_i
      data = {:tx => [], :rx => []}
      date_keys = $redis.keys("interface_#{i.id}_sample_*").sort
      data = faker_values({:size => 12, :keys => {:rx => Rails.env.production? ? 0: speed * 0.99, :tx => Rails.env.production? ? 0 : speed * 0.99}}) if date_keys.empty?

      date_keys.each do |key|
        time = $redis.hget("#{key}", "time").to_i* 1000
        value_up = 0
        value_down = 0
        rkey_down.each do |rkey|
          value_rx += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
        end
        rkey_up.each do |rkey|
          value_tx += $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
        end
        data[:rx] << [time, value_rx]
        data[:tx] << [time, value_tx]
      end
      datas << data
    end

    series = []

    unless datas.empty?
      datas = datas.sum
      series << { :name => "rx", :type=> "spline", :color=> GREEN, :marker => { :enabled=> false }, :stack => "rx", :data => datas[:rx].sort }
      series << { :name => "tx", :type=> "spline", :color=> RED,   :marker => { :enabled=> false }, :stack => "tx", :data => datas[:tx].sort }
    end

    graph = { :title =>'',
              :render_to => render_to,
              :ytitle => '',
              :legend => false,
              :series => series }

    { render_to => default_options_graphs(graph) }
  end

end
