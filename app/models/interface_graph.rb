class InterfaceGraph < Graph
  GRAPHS = [ "interface_instant", "provider_group_instant" ]

  InterfaceSample::CONF_PERIODS.each_value do |key|
    GRAPHS << "interface_period_#{key[:period_number]}"
    GRAPHS << "provider_group_period_#{key[:period_number]}"

    define_method("interface_period_#{key[:period_number]}") do
      series = []
      period = key[:period_number]
      speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
      samples = InterfaceSample.all( :conditions => { :interface_id => @model.id,
                                                      :period => period } )

      InterfaceSample.compact_keys.each do |rkey|
        data = if Rails.env.production?
                 samples.map { |s| [ ((s.sample_number.to_i + Time.now.utc_offset) * 1000), s[rkey[:name].to_sym] ] }
               else
                 faker_values({ :size => key[:sample_size],
                                :time => (key[:scope] * 1000),
                                :keys => { rkey[:name] => speed * 0.99 } })[rkey[:name]]
               end

        series << { :name  => rkey[:name],
                    :type  => "spline",
                    :stack => rkey[:name],
                    :data  => data.sort }
      end

      graph = { :title  => I18n.t("graphs.titles.interfaces.#{(__method__).to_s}"),
                :ytitle => 'bps(bits/second)',
                :tooltip_formatter => "function() { return '<b>'+ this.series.name + '</b><br/>' + Highcharts.numberFormat(this.y, 2) + 'b/s'}",
                :series => series }

      default_options_graphs(graph)
    end

    define_method("provider_group_period_#{key[:period_number]}") do
      series = []
      period = key[:period_number]
      interfaces = @model.providers.map{ |p| p.interface }

      InterfaceSample.compact_keys.each do |rkey|
        data = interfaces.empty? ? faker_values({ :size => key[:sample_size], :time => (key[:scope] * 1000), :keys => { rkey[:name] => Rails.env.production? ? 0 : (100 * 0.99) } })[rkey[:name]] : {}
        InterfaceSample.all( :conditions => { :interface_id => interfaces.map(&:id), :period => period } ).each do |s|
          time = (s[:sample_number] + Time.now.utc_offset) * 1000
          data[time] = 0 unless data.has_key?(time)
          data[time] += s[rkey[:name]]
        end

        series << { :name  => rkey[:name],
                    :type  => "spline",
                    :stack => rkey[:name],
                    :data  => data.to_a.sort }
      end

      graph = { :title  => I18n.t("graphs.titles.provider_groups.#{(__method__).to_s}"),
                :ytitle => 'bps(bits/second)',
                :tooltip_formatter => "function() { return '<b>'+ this.series.name + '</b><br/>' + Highcharts.numberFormat(this.y, 2) + 'b/s'}",
                :series => series }

      default_options_graphs(graph)
    end
  end

  def interface_instant
    series = []
    speed = @model.speed.map {|x| x[/\d+/]}.first.to_i
    date_keys = $redis.keys("interface_#{@model.id}_sample_*").sort

    InterfaceSample.compact_keys.each do |rkey|
      data = date_keys.empty? ? faker_values({ :size => 12,
                                               :time => (5 * 1000),
                                               :keys => {rkey[:name] => Rails.env.production? ? 0: speed * 0.99}})[rkey[:name]] : []

      date_keys.each do |key|
        time = ($redis.hget("#{key}", "time").to_i + Time.now.utc_offset) * 1000
        value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
        data << [ time, value ]
      end

      series << { :name   => rkey[:name],
                  :type   => "spline",
                  :marker => { :enabled => false },
                  :stack  => rkey[:name],
                  :data   => data.sort }
    end

    graph = { :title  => I18n.t("graphs.titles.interfaces.#{(__method__).to_s}"),
              :ytitle => 'bps(bits/second)',
              :tooltip_formatter => "function() { return '<b>'+ this.series.name + '</b><br/>' + Highcharts.numberFormat(this.y, 2) + 'b/s'}",
              :series => series }

    default_options_graphs(graph)
  end

  def provider_group_instant
    interfaces = @model.providers.map{ |p| p.interface }
    series = []

    InterfaceSample.compact_keys.each do |rkey|
      data = interfaces.empty? ? faker_values({ :size => 12,
                                                :time => (5 * 1000),
                                                :keys => {rkey[:name] => Rails.env.production? ? 0: 100 * 0.99}})[rkey[:name]] : {}
      interfaces.each do |i|
        date_keys = $redis.keys("interface_#{i.id}_sample_*").sort
        date_keys.each do |key|
          unless data.has_key?(key)
            time = $redis.hget("#{key}", "time").to_i * 1000
            data[time] = 0 unless data.has_key?(time)
            value = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
            data[time] += value
          end
        end
      end

      series << { :name   => rkey[:name],
                  :type   => "spline",
                  :marker => { :enabled => false },
                  :stack  => rkey[:name],
                  :data   => data.to_a.sort }
    end



    graph = { :title  => I18n.t("graphs.titles.provider_groups.#{(__method__).to_s}"),
              :ytitle => 'bps(bits/second)',
              :tooltip_formatter => "function() { return '<b>'+ this.series.name + '</b><br/>' + Highcharts.numberFormat(this.y, 2) + 'b/s'}",
              :series => series }

    default_options_graphs(graph)
  end

  def self.supported_graph(obj)
    GRAPHS.select{|g| g.include?(obj.class.name.underscore)}
  end

end
