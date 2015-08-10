class ContractGraph < Graph
  GRAPHS = [ "rate_up_instant", "rate_down_instant", "total_rate", "latency_instant", "data_count" ]

  ContractSample::CONF_PERIODS.each_value do |key|
    ["up", "down"].each do |up_or_down|
      GRAPHS << "rate_#{up_or_down}_period_#{key[:period_number]}"
    end
  end

  # Dynamic method for up and down
  ["up", "down"].each do |up_or_down|
    define_method("rate_#{up_or_down}_instant") do
      data = {}
      plan = @model.plan
      date_keys = $redis.keys("contract_#{@model.id}_sample_*").sort

      ContractSample.compact_keys.select{ |k| k[:up_or_down] == up_or_down }.each do |rkey|
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

      graph = { :title => I18n.t("graphs.titles.instant_rate_#{up_or_down}"),
                :type => 'areaspline',
                :stacking => 'normal',
                :ytitle => 'bps(bits/second)',
                :series => [] }

      data.each do |key, value|
        graph[:series] << { :name => key, :type=> "areaspline", :stack => up_or_down, :data => value }
      end

      default_options_graphs(graph)
    end

    # Dynamic method for each period
    ContractSample::CONF_PERIODS.each_value do |key|
      define_method("rate_#{up_or_down}_period_#{key[:period_number]}") do
        period = key[:period_number]
        samples = ContractSample.all(:conditions => { :contract_id => @model.id, :period => period } )

        data = {}
        ContractSample.compact_keys.each do |rkey|
          if rkey[:up_or_down] == up_or_down
            data[rkey[:name]] = []
            samples.each do |sample|
              # value = rkey[:name].include?("up")? sample[rkey[:name].to_sym]*-1 : sample[rkey[:name].to_sym]
              data[rkey[:name]] << [ ((sample.sample_number.to_i + Time.now.utc_offset) * 1000), sample[rkey[:name].to_sym] ]
            end
          end
        end

        graph = { :title => I18n.t("graphs.titles.rate_#{up_or_down}_period_#{period}"),
                  :type => 'areaspline',
                  :stacking => 'normal',
                  :ytitle => 'bps(bits/second)',
                  :series => [] }

        data.each do |key, value|
          graph[:series] << { :name => key, :type=> "areaspline", :stack => up_or_down, :data => value }
        end
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

    graph = { :title => I18n.t("graphs.titles.total_rate"),
              :ytitle => 'bps(bits/second)',
              :series => series }

    default_options_graphs(graph)
  end

  def latency_instant
    data = { :ping => [], :arping => [] }

    # date_time_now = (DateTime.now.to_i + Time.now.utc_offset) * 1000
    # 12.times do |i|
    #   data[:ping] << [date_time_now - (i * 1000), 0]
    #   data[:arping] << [date_time_now - (i * 1000), 0]
    # end

    data = faker_values({ :size => 12, :keys => { :ping => 3, :arping => 3 } }) unless Rails.env.production?

    series = [ { :name => 'ping',   :color => GREEN, :type => 'spline', :data => data[:ping] },
               { :name => 'arping', :color => RED,   :type => 'spline', :data => data[:arping] } ]

    graph = { :title => I18n.t("graphs.titles.latency"),
              :ytitle => "Miliseconds",
              :series => series }

    default_options_graphs(graph)
  end

  def data_count
    series = [{ :name => I18n.t('graph.traffic'), :type => 'column', :data => @model.data_count_for_last_year }]

    graph = { :title => I18n.t("graphs.titles.data_count"),
              :ytitle => I18n.t('graph.data'),
              :xtype => 'category',
              :series => series }

    default_options_graphs(graph)
  end
end
