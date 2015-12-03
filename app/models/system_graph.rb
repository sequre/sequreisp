class SystemGraph < Graph
  GRAPHS = ["load_average_instant", "ram"]

  MoolDisk.all.each do |disk|
    GRAPHS << "disk_#{disk.logical_name}"
    define_method("disk_#{disk.logical_name}") do
      foo = []
      bar = []

      disk_size = disk.total_block

      first_parts = (disk.partitions + disk.slaves)

      if first_parts.empty?
        foo <<  { :name => disk.logical_name,
                  :y => disk.total_block }

        bar <<  { :name => 'Free',
                  :y => disk.total_block - disk.block_used,
                  :color => GREEN }
        bar <<  { :name => 'Used',
                  :y => disk.block_used,
                  :color => RED }
      else
        first_parts.each do |part|
          unless part.swap
            second_parts = part.partitions + part.slaves
            if second_parts.empty?
              foo << { :name => part.logical_name,
                       :y => part.total_block }

              bar << { :name => 'Free',
                       :y => part.total_block - part.block_used,
                       :color => GREEN }
              bar << { :name => 'Used',
                       :y => part.block_used,
                       :color => RED }
            else
              second_parts.each do |second_part|
                unless second_part.swap
                  foo << { :name =>"#{part.logical_name}-#{second_part.logical_name}",
                           :y => second_part.total_block }

                  bar << { :name => 'Free',
                           :y => second_part.total_block - second_part.block_used,
                           :color => GREEN }
                  bar << { :name => 'Used',
                           :y => second_part.block_used,
                           :color => RED }
                end
              end
            end
          end
        end
      end

      header = { :name => 'Browsers',
                 :size => '60%',
                 :data => foo,
                 :dataLabels => {
                   :formatter => "function () { return this.y > 5 ? this.point.name : null; }",
                   :color => '#ffffff',
                   :distance => -30 }
               }

      body = { :name => 'Versions',
               :size => '80%',
               :innerSize => '60%',
               :data => bar }

      graph = { :title  => I18n.t("graphs.titles.disk", :name => disk.logical_name),
                :type   => "pie",
                :series => [header, body] }

      default_options_graphs(graph)
    end
  end

  swap_disk = MoolDisk.swap
  GRAPHS << "swap_disk_#{swap_disk.logical_name}"
  define_method("swap_disk_#{swap_disk.logical_name}") do
    series = [ { :colorByPoint => true,
                 :data => [ { :name => 'Used',
                              :color => RED,
                              :sliced => true,
                              :selected => true,
                              :y => (swap_disk.block_used / 2**20).round(2) },
                            { :name => 'Free',
                              :color => GREEN,
                              :y => ((swap_disk.total_block - swap_disk.block_used) / 2**20).round(2) } ] }]

    graph = { :title  => "swap: #{swap_disk.logical_name}",
              :type   => "pie",
              :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.y +' MB'}",
              :series => series }

    default_options_graphs(graph)
  end

  # Dashboard::Disk.load_all.each do |disk|
  #   disk_name = disk.device.split('/').last.split('-').last
  #   GRAPHS << "disk_#{disk_name}"
  #   define_method("disk_#{disk_name}") do

  #   series = [ { :colorByPoint => true,
  #                :data => [ { :name => disk.data[1][:name],
  #                             :color => RED,
  #                             :sliced => true,
  #                             :selected => true,
  #                             :y => disk.data[1][:y] },
  #                           { :name => disk.data[0][:name],
  #                             :color => GREEN,
  #                             :y => disk.data[0][:y] }] } ]

  #   graph = { :title  => I18n.t("graphs.titles.disk", :name => disk_name),
  #             :type   => "pie",
  #             :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.percentage +' %'}",
  #             :series => series }

  #   default_options_graphs(graph)
  #   end
  # end

  def ram
    ram = MoolMemory.new.to_mb

    series = [ { :colorByPoint => true,
                 :data => [ { :name => 'Used',
                              :color => RED,
                              :sliced => true,
                              :selected => true,
                              :y => ram.mem_used.round },
                            { :name => 'Free',
                              :color => GREEN,
                              :y => ram.mem_free.round } ] }]

    graph = { :title  => I18n.t("graphs.titles.ram"),
              :type   => "pie",
              :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.y +' MB'}",
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

  MoolCpu.all.each do |cpu|
    GRAPHS << "#{cpu.cpu_name}_instant"
    define_method("#{cpu.cpu_name}_instant") do
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

      core_number = cpu.cpu_name.split("_").last

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
