class InterfaceGraph < Graph
  GRAPHS = [ "instant", "interface_group_instant" ]

  InterfaceSample::CONF_PERIODS.each_value do |key|
    GRAPHS << "interface_period_#{key[:period_number]}"
    GRAPHS << "interface_group_period_#{key[:period_number]}"

    define_method("interface_period_#{key[:period_number]}") do
      period = key[:period_number]
      speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
      samples = InterfaceSample.all( :conditions => { :interface_id => @model.id, :period => period } )

      series = []
      InterfaceSample.compact_keys.each do |rkey|
        data = if Rails.env.production?
                 samples.map { |s| [ (s.sample_number.to_i * 1000), s[rkey[:name].to_sym] ] }
               else
                 faker_values({ :size => key[:sample_size],
                                :keys => { rkey[:name].to_sym => speed * 0.99 } })[rkey[:name].to_sym]
               end

        series << { :name  => rkey[:name],
                    :type  => "spline",
                    :stack => rkey[:name],
                    :data  => data }
      end

      graph = { :title         => I18n.t("graphs.titles.instant_period_#{period}"),
                :ytitle        => 'bps(bits/second)',
                :series        => series }

      default_options_graphs(graph)
    end

    define_method("interface_group_period_#{key[:period_number]}") do
      series = []
      period = key[:period_number]
      interfaces = @model.providers.map{ |p| p.interface }

      InterfaceSample.compact_keys.each do |rkey|
        data = interfaces.empty? ? faker_values({ :size => key[:sample_size], :keys => { rkey[:name].to_sym => Rails.env.production? ? 0 : (100 * 0.99) } }) : {}
        InterfaceSample.all( :conditions => { :interface_id => interfaces.map(&:id), :period => period } ).each do |s|
          data[s[:sample_number]] = 0 unless data.has_key?(s[:sample_number])
          data[s[:sample_number]] += data[rkey[:name]]
        end

        series << { :name  => rkey[:name],
                    :type  => "spline",
                    :stack => rkey[:name],
                    :data  => data.to_a }
      end

      graph = { :title    => I18n.t("graphs.titles.interface_group_period_#{period}"),
                :ytitle   => 'bps(bits/second)',
                :series   => series }

      default_options_graphs(graph)
    end
  end

  def instant
    series = []
    speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
    date_keys = $redis.keys("interface_#{@model.id}_sample_*").sort

    InterfaceSample.compact_keys.each do |rkey|
      data = date_keys.empty? ? faker_values({ :size => 12, :keys => {rkey[:name].to_sym => Rails.env.production? ? 0: speed * 0.99}})[rkey[:name].to_sym] : []

      if Rails.env.production?
        date_keys.each do |key|
          time = $redis.hget("#{key}", "time").to_i * 1000
          value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
          data << [ time, value ]
        end
      end

      series << { :name   => rkey[:name],
                  :type   => "spline",
                  :marker => { :enabled => false },
                  :stack  => rkey[:name],
                  :data   => data }
    end

    graph = { :title  => I18n.t("graphs.titles.interface_instant"),
              :ytitle => 'bps(bits/second)',
              :series => series }

    default_options_graphs(graph)
  end

  def interface_group_instant
    interfaces = @model.providers.map{ |p| p.interface }
    series = []

    InterfaceSample.compact_keys.each do |rkey|
      data = interfaces.empty? ? faker_values({ :size => 12, :keys => {rkey[:name].to_sym => Rails.env.production? ? 0: 100 * 0.99}}) : {}
      interfaces.each do |i|
        date_keys = $redis.keys("interface_#{i.id}_sample_*").sort
        date_keys.each do |key|
          data[time] = 0 unless data.has_key?(key)
          time = $redis.hget("#{key}", "time").to_i * 1000
          value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
          data[time] += value
        end
      end

      series << { :name   => rkey[:name],
                  :type   => "spline",
                  :marker => { :enabled => false },
                  :stack  => rkey[:name],
                  :data   => data.to_a }
    end

    graph = { :title => I18n.t("graphs.titles.interface_group_instant"),
              :ytitle => 'bps(bits/second)',
              :series => series }

    default_options_graphs(graph)
  end

end
