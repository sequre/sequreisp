class SystemGraph < Graph
  GRAPHS = ["load_average_instant", "ram"]

  def build_partition_data(disk, partition_name=nil)
    return if disk.swap
    partition_name ||= disk.logical_name

    @partitions_graph << { :name => partition_name,
                           :y => (disk.total_block / 2**30).round(2),
                           :color => @disk_partition_color.pop }

    @sizes_graph << { :name => I18n.t("graphs.titles.disks.free"),
                      :y => ((disk.total_block - disk.block_used) / 2**30).round(2),
                      :color => GREEN }

    @sizes_graph << { :name => I18n.t("graphs.titles.disks.used"),
                      :y => (disk.block_used  / 2**30).round(2),
                      :color => RED }
  end

  MoolDisk.all.each do |disk|
    GRAPHS << "disk_#{disk.logical_name}"
    define_method("disk_#{disk.logical_name}") do
      @partitions_graph = []
      @sizes_graph = []
      @disk_partition_color = [ "#789cb4", "#75509b", "#ef5836", "#493829", "#c04a67", "#a5bdcd", "#6b6a6a", "#39b9a1", "#1f5b83" ]

      first_parts = (disk.partitions + disk.slaves)

      if first_parts.empty?
        build_partition_data(disk)
      else
        first_parts.each do |part|
          second_parts = part.partitions + part.slaves
          second_parts.empty? ? build_partition_data(part) : second_parts.each { |spart| build_partition_data(spart, "#{part.logical_name}-#{spart.logical_name}" ) }
        end
      end

      header = { :name => I18n.t("graphs.titles.disks.partition"),
                 :size => '60%',
                 :data => @partitions_graph,
                 :dataLabels => {
                   :formatter => "function () { return this.y > 5 ? this.point.name : null; }",
                   :color => '#ffffff',
                   :distance => -30 }
               }

      body = { :name => I18n.t("graphs.titles.disks.size"),
               :size => '80%',
               :innerSize => '60%',
               :data => @sizes_graph }

      graph = { :title  => I18n.t("graphs.titles.disk", { :name => disk.logical_name, :size => "#{(disk.total_block / 2**30).round(2)} GB"} ),
                :type   => "pie",
                :series => [header, body] }

      default_options_graphs(graph)
    end
  end

  swap_disk = MoolDisk.swap
  if swap_disk
    GRAPHS << "swap_disk_#{swap_disk.logical_name}"
    define_method("swap_disk_#{swap_disk.logical_name}") do
      series = [ { :colorByPoint => true,
                   :data => [ { :name => I18n.t("graphs.titles.disks.used"),
                                :color => RED,
                                :sliced => true,
                                :selected => true,
                                :y => (swap_disk.block_used / 2**20).round(2) },
                              { :name => I18n.t("graphs.titles.disks.free"),
                                :color => GREEN,
                                :y => ((swap_disk.total_block - swap_disk.block_used) / 2**20).round(2) } ] }]

      graph = { :title  => "swap: #{swap_disk.logical_name}",
                :type   => "pie",
                :tooltip_formatter => "function () {return '<b>'+ this.point.name +'</b>: '+ this.y +' MB'}",
                :series => series }

      default_options_graphs(graph)
    end
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
                 :data => [ { :name => I18n.t("graphs.titles.disks.used"),
                              :color => RED,
                              :sliced => true,
                              :selected => true,
                              :y => ram.mem_used.round },
                            { :name => I18n.t("graphs.titles.disks.free"),
                              :color => GREEN,
                              # :y => ram.mem_available.round } ] }]
                              :y => (ram.mem_free + ram.cached + ram.buffers).round } ] }]

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
