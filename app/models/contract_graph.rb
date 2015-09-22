class ContractGraph < Graph
  GRAPHS = [ "rate_up_instant", "rate_down_instant", "total_rate", "latency_instant", "data_count" ]

  # Dynamic method for up and down
  ["up", "down"].each do |up_or_down|
    define_method("rate_#{up_or_down}_instant") do
      series = []
      data = {}
      plan = @model.plan
      date_keys = $redis.keys("contract_#{@model.id}_sample_*").sort

      ContractSample.compact_keys.select{ |k| k[:up_or_down] == up_or_down }.each do |rkey|
        data = []
        if Rails.env.production?
          date_keys.each do |key|
            time = ($redis.hget("#{key}", "time").to_i + Time.now.utc_offset) * 1000
            value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
            data << [ time, value ]
          end
        else
          date_time_now = (DateTime.now.to_i + Time.now.utc_offset) * 1000
          12.times do |i|
            date = date_time_now - (i * 1000)
            value = plan.send("ceil_#{rkey[:up_or_down]}") * rand(0.99)
            data << [ date, value ]
          end
        end

        data = add_empty_values( {:data => data, :size => 12} )

        series << { :name  => rkey[:name],
                    :type  => "spline",
                    :stack => rkey[:up_or_down],
                    :data  => data.sort }
      end

      graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
                :ytitle => 'bps(bits/second)',
                :tooltip_formatter => "function() { return '<b>'+ this.series.name +'</b><br/>'+ Highcharts.numberFormat(this.y, 2) + 'b/s'}",
                :series => series }

      default_options_graphs(graph)
    end

    # Dynamic method for each period
    ContractSample::CONF_PERIODS.each_value do |key|
      GRAPHS << "rate_#{up_or_down}_period_#{key[:period_number]}"
      define_method("rate_#{up_or_down}_period_#{key[:period_number]}") do
        series = []
        period = key[:period_number]
        samples = ContractSample.all(:conditions => { :contract_id => @model.id,
                                                      :period => period } )

        ContractSample.compact_keys.select{ |k| k[:up_or_down] == up_or_down }.each do |rkey|
          data = []
          samples.each do |sample|
            time = (sample.sample_number.to_i + Time.now.utc_offset) * 1000
            value = sample[rkey[:name].to_sym]
            data << [ time, value ]
          end

          data = add_empty_values( {:data => data, :size => 12} )

          series << { :name  => rkey[:name],
                      :type  => "areaspline",
                      :stack => rkey[:up_or_down],
                      :data  => data.sort }
        end

        graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
                  :ytitle => 'bps(bits/second)',
                  :tooltip_formatter => "function() { return '<b>'+ this.series.name +'</b><br/>'+ Highcharts.numberFormat(this.y, 2) + 'b/s'}",
                  :series => series }

        default_options_graphs(graph)
      end
    end
  end

  def total_rate
    plan = @model.plan
    data = {:up => [], :down => []}
    date_keys = $redis.keys("contract_#{@model.id}_sample_*")
    rkey_down = ContractSample.compact_keys.select{ |a| a[:up_or_down] == "down" }
    rkey_up   = ContractSample.compact_keys.select{ |a| a[:up_or_down] == "up" }

    data = faker_values({ :size => 12,
                          :time => (5 * 1000),
                          :keys => { :up   => Rails.env.production? ? 0 : plan.ceil_up,
                                     :down => Rails.env.production? ? 0 : plan.ceil_down } }) if date_keys.empty?

    date_keys.sort.each do |key|
      time = ($redis.hget("#{key}", "time").to_i + Time.now.utc_offset) * 1000
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

    data[:up] = add_empty_values( {:data => data[:up], :size => 12} )
    data[:down] = add_empty_values( {:data => data[:down], :size => 12} )

    series = [ { :name   => "up",
                 :type   => "spline",
                 :color  => RED,
                 :marker => { :enabled => false },
                 :stack  => "up",
                 :data   => data[:up].sort },

               { :name   => "down",
                 :type   => "spline",
                 :color  => GREEN,
                 :marker => { :enabled => false },
                 :stack  => "down",
                 :data   => data[:down].sort } ]

    graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
              :ytitle => 'bps(bits/second)',
              :tooltip_formatter => "function() { return '<b>'+ this.series.name +'</b><br/>'+ Highcharts.numberFormat(this.y, 2) + 'b/s' }",
              :series => series }

    default_options_graphs(graph)
  end

  def latency_instant
    data = { :ping => [], :arping => [] }

    data = faker_values({ :size => 12,
                          :time => (5 * 1000),
                          :keys => { :ping => Rails.env.production? ? 0 : 3,
                                     :arping => Rails.env.production? ? 0 : 3 } })

    series = [ { :name  => 'ping',
                 :color => GREEN,
                 :type  => 'spline',
                 :data  => data[:ping].sort },
               { :name  => 'arping',
                 :color => RED,
                 :type  => 'spline',
                 :data  => data[:arping].sort } ]

    graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
              :ytitle => "Milliseconds",
              :tooltip_formatter => "function() { return '<b>'+ this.series.name + '</b><br/>' + Highcharts.numberFormat(this.y, 2) + 'ms'}",
              :series => series }

    default_options_graphs(graph)
  end

  def data_count
    series = [{ :name => I18n.t('graph.traffic'),
                :type => 'column',
                :data => @model.data_count_for_last_year }]

    graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
              :ytitle => I18n.t('graph.data'),
              :xtype  => 'category',
              :tooltip_formatter => "function() { return '<b>'+ this.series.name +'</b><br/>'+ Highcharts.numberFormat(this.y, 2) + 'Bytes' }",
              :series => series }

    default_options_graphs(graph)
  end

  def self.supported_graphs
    GRAPHS
  end

end
