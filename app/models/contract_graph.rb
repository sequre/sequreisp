class ContractGraph < Graph
  GRAPHS = [ "rate_up_instant", "rate_down_instant", "total_rate_instant", "latency_instant", "data_count" ]
  COLORS = {"up" => RED, "down" => GREEN, "prio1" => RED, "prio2" => GREEN, "prio3" => VIOLET, "supercache" => BLUE }

  # Dynamic method for up and down
  ["up", "down"].each do |up_or_down|
    define_method("rate_#{up_or_down}_instant") do
      series = []
      data = {}
      plan = @model.plan
      # date_keys = $redis.keys("contract_#{@model.id}_sample_*").sort
      date_keys = $redis.hgetall("#{@model.redis_key}_keys").values.sort

      ContractSample.compact_keys.select{ |k| k[:up_or_down] == up_or_down }.each do |rkey|
        data = []
        if Rails.env.production?
          date_keys.each do |key|
            time = ($redis.hget("#{key}", "time").to_i + Time.now.utc_offset) * 1000
            value = (($redis.hget("#{key}", "#{rkey[:name]}_instant").to_f / $redis.hget("#{key}", "total_seconds").to_f) * 8).to_f
            value = value.nan? ? 0 : value.round
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
                    :color => COLORS[rkey[:sample]],
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
        samples = ContractSample.all(:conditions => { :contract_id => @model.id, :period => period } )

        ContractSample.compact_keys.select{ |k| k[:up_or_down] == up_or_down }.each do |rkey|
          data = []
          samples.each do |sample|
            time = (sample.sample_number.to_i + Time.now.utc_offset) * 1000
            value = sample[rkey[:name].to_sym]
            data << [ time, value ]
          end

          series << { :name  => rkey[:name],
                      :type  => "spline",
                      :color => COLORS[rkey[:sample]],
                      :stack => rkey[:up_or_down],
                      :data  => data.sort,
                      :tooltip => {:valueSuffix => ' b/s'} }
        end

        graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
                  :ytitle => 'bps(bits/second)',
                  :series => series }

        default_options_graphs(graph)
      end
    end
  end

  # Dynamic method for each period
  ContractSample::CONF_PERIODS.each_value do |key|
    GRAPHS << "total_rate_period_#{key[:period_number]}"
    define_method("total_rate_period_#{key[:period_number]}") do
      series = []
      period = key[:period_number]
      samples = ContractSample.all(:conditions => { :contract_id => @model.id, :period => period } )

      ["up", "down"].each do |up_or_down|
        data = []
        rkeys = ContractSample.compact_keys.select{ |a| a[:up_or_down] == up_or_down }
        samples.each do |sample|
          total = 0
          time = (sample.sample_number.to_i + Time.now.utc_offset) * 1000
          rkeys.each do |rkey|
            total += sample[rkey[:name]]
          end
          data << [time, total]
        end
        series << { :name  => up_or_down,
                    :type  => "spline",
                    :color => COLORS[up_or_down],
                    :stack => up_or_down,
                    :data  => data.sort,
                    :tooltip => {:valueSuffix => ' b/s'} }
      end

      graph = { :title  => I18n.t("graphs.titles.contracts.#{(__method__).to_s}"),
                :ytitle => 'bps(bits/second)',
                :series => series }

      default_options_graphs(graph)
    end
  end

  def total_rate_instant
    plan = @model.plan
    # date_keys = $redis.keys("contract_#{@model.id}_sample_*")
    date_keys = $redis.hgetall("#{@model.redis_key}_keys").values
    series = []

    ["up", "down"].each do |up_or_down|
      data = []
      rkeys = ContractSample.compact_keys.select{ |a| a[:up_or_down] == up_or_down }

      data = date_keys.empty? ? faker_values({ :size => 12,
                                               :time => (5 * 1000),
                                               :keys => { :key => Rails.env.production? ? 0 : plan.send("ceil_#{up_or_down}") } })[:key] : []
      date_keys.sort.each do |key|
        time = ($redis.hget("#{key}", "time").to_i + Time.now.utc_offset) * 1000
        total = 0
        rkeys.each do |rkey|
          val = (($redis.hget("#{key}", "#{rkey[:name]}_instant").to_f / $redis.hget("#{key}", "total_seconds").to_f) * 8).to_f
          total += val.nan? ? 0 : val.round
        end
        data << [time, total]
      end

      data = add_empty_values( {:data => data.sort, :size => 12} )

      series << { :name   => up_or_down,
                  :type   => "spline",
                  :color  => COLORS[up_or_down],
                  :marker => { :enabled => false },
                  :stack  => up_or_down,
                  :data   => data }
    end

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
                :color => GREEN,
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
