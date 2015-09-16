class SystemGraph < Graph
  GRAPHS = ["load_average_instant", "ram"]

  Dashboard::Disk.load_all.each do |disk|
    disk_name = disk.device.split('/').last.split('-').last
    GRAPHS << "disk_#{disk_name}"
    define_method("disk_#{disk_name}") do

    series = [ { :colorByPoint => true,
                 :data => [ { :name => disk.data[1][:name],
                              :color => RED,
                              :sliced => true,
                              :selected => true,
                              :y => disk.data[1][:y] },
                            { :name => disk.data[0][:name],
                              :color => GREEN,
                              :y => disk.data[0][:y] }] } ]

    graph = { :title  => I18n.t("graphs.titles.disk", :name => disk_name),
              :type   => "pie",
              :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.percentage +' %'}",
              :series => series }

    default_options_graphs(graph)
    end
  end

  def ram
    ram = Dashboard::Memory.new(/Mem:/)

    series = [ { :colorByPoint => true,
                 :data => [ { :name => 'used',
                              :color => RED,
                              :sliced => true,
                              :selected => true,
                              :y => ram.used },
                            { :name => 'free',
                              :color => GREEN,
                              :y => ram.free } ] }]

    graph = { :title  => I18n.t("graphs.titles.ram"),
              :type   => "pie",
              :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.percentage +' %'}",
              :series => series }

    default_options_graphs(graph)
  end

  def load_average_instant

    data = faker_values({ :size => 12,
                          :time => (5 * 1000),
                          :keys => { :now   => 0,
                                     :min5  => 0,
                                     :min15 => 0 } })

    series = [ { :name => 'now',
                 :color => GREEN,
                 :type  => "spline",
                 :data => data[:now] },
               { :name => 'min5',
                 :color => RED,
                 :type  => "spline",
                 :data => data[:min5] },
               { :name => 'min15',
                 :color => BLUE,
                 :type  => "spline",
                 :data => data[:min15] } ]


    graph = { :title  => I18n.t("graphs.titles.load_average"),
              :ytitle => "percentage",
              :tooltip_formatter => "function() {return '<b>'+ this.series.name +'</b><br/>'+Highcharts.numberFormat(this.y, 2)}",
              :series => series }

    default_options_graphs(graph)
  end

  Dashboard::Cpu.new.stats.each do |key, sample|
    GRAPHS << "#{key}_instant"
    define_method("#{key}_instant") do
      data = { :total => [], :kernel => [], :iowait => [] }

      data = faker_values({ :size => 12,
                            :time => (5 * 1000),
                            :keys => { :total  => 0,
                                       :kernel => 0,
                                       :iowait => 0 } })

      series = [ { :name  => 'Total',
                   :color => GREEN,
                   :type  => "spline",
                   :data  => data[:total] },
                 { :name  => 'Kernel',
                   :color => RED,
                   :type  => "spline",
                   :data  => data[:kernel] },
                 { :name  => 'IO/Wait',
                   :color => BLUE,
                   :type  => "spline",
                   :data  => data[:iowait] } ]

      core_number = key.split("_").last

      title = (core_number == "all")? I18n.t("graphs.titles.cpu_average") : I18n.t("graphs.titles.cpu", :number => core_number )

      graph = { :title  => title,
                :ytitle => "percentage",
                :tooltip_formatter => "function() {return '<b>'+ this.series.name +'</b><br/>'+Highcharts.numberFormat(this.y, 2)}",
                :series => series }

    default_options_graphs(graph)
    end
  end


  def self.supported_graphs
    GRAPHS
  end

end
