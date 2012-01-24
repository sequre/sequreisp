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
  RRD_DB_DIR=RAILS_ROOT + "/db/rrd"
  RRD_IMG_DIR=RAILS_ROOT + "/public/images/rrd"
  attr_accessor :element
  def initialize(options)
    @element = nil
    if options[:element].nil? 
      if (not options[:class].nil?) and (not options[:id].nil?)
        @element = options[:class].constantize.find options[:id]
      end 
    else
      @element = options[:element]
    end
    raise "Undefined :element or :class,:id" if @element.nil?
  end
  def name
    case element.class.to_s
    when "Contract"
      "#{element.client.name}"
    when "Provider", "ProviderGroup", "Interface"
      "#{element.name}"
    end
  end
  def img(mtime, msize)
    width = 0
    height = 0
    time = 0
    xgrid = 0
    case mtime
    when "hour"
      time = "-1h"
      xgrid = "MINUTE:10:MINUTE:30:MINUTE:30:0:\%H:\%M"
    when "day"
      time = "-1d"
      xgrid = "MINUTE:30:HOUR:1:HOUR:3:0:\%H:\%M"
    when "week"
      time = "-7d"
      xgrid = "HOUR:6:DAY:1:DAY:1:0:\%a-\%d"
    when "month"
      time = "-1m"
      xgrid = "DAY:1:DAY:7:DAY:7:0:\%d-\%b"
    when "year"
      time = "-1y"
      xgrid = "MONTH:1:MONTH:1:MONTH:1:0:\%b"
    end
    case msize 
    when "small"
      width = 150
      height = 62
      xgrid = "HOUR:6:HOUR:6:HOUR:6:0:\%Hhs"
      graph_small(time, xgrid, width, height)
    when "medium"
      width = 500
      height = 60
      graph(time, xgrid, width, height) 
    when "large"
      width = 650 
      height = 180
      graph(time, xgrid, width, height) 
    end
  end
  def path_rrd
    RRD_DB_DIR + "/#{element.class.to_s}.#{element.id}.rrd"
  end
  def path_img(gname)
    RRD_IMG_DIR + "/#{gname}.png"
  end
  def rrd_graph(args=[])
    begin
      eval "RRD::Wrapper.graph!(" + args.collect{ |n| "'" + n +  "'" }.join(",") + ")"
    rescue => e
      Rails.logger.error "ERROR: Graph::grpah #{e.inspect}"
      nil
    end
  end
  def rrd_args_for_element
    case element.class.to_s
    when "Interface"
      [
        "AREA:down_prio_#00AA00:down",
        "LINE1:up_prio_#FF0000:up",
        "HRULE:#{element.rate_down*1024}#00AA0066",
        "HRULE:#{element.rate_up*1024}#FF000066",
        "--upper-limit=#{element.rate_down*1000}",
      ] 
    when "Provider", "ProviderGroup"
      args = [ "AREA:down_prio_#00AA00:down" ] 
      args += [ "STACK:down_dfl_#00EE00:down p2p" ] if Configuration.first.use_global_prios
      args += [ "LINE1:up_prio_#FF0000:up" ]
      args += [ "STACK:up_dfl_#FF6600:up p2p" ] if Configuration.first.use_global_prios
      args += 
      [  
        "HRULE:#{element.rate_down*1024}#00AA0066",
        "HRULE:#{element.rate_up*1024}#FF000066",
        "--upper-limit=#{element.rate_down*1000}",
      ] 
    when "Contract"
      [
        "AREA:down_prio_#00AA00:down",
        "STACK:down_dfl_#00EE00:down p2p",
        "LINE1:up_prio_#FF0000:up",
        "STACK:up_dfl_#FF6600:up p2p",
        "HRULE:#{element.plan.ceil_down*1024}#00AA0066",
        "HRULE:#{element.plan.ceil_up*1024}#FF000066",
        "--upper-limit=#{element.plan.ceil_down*1000}",
      ] 
    end
  end
  def rrd_default_args(gname, time, xgrid, width, height)
    [
      path_img(gname),
      "-s", time,
      "DEF:down_prio=#{path_rrd}:down_prio:AVERAGE",
      "DEF:down_dfl=#{path_rrd}:down_dfl:AVERAGE",
      "DEF:up_prio=#{path_rrd}:up_prio:AVERAGE",
      "DEF:up_dfl=#{path_rrd}:up_dfl:AVERAGE",
      "CDEF:down_prio_=down_prio,8,*",
      "CDEF:down_dfl_=down_dfl,8,*",
      "CDEF:down_=down_prio_,down_dfl_,+",
      "CDEF:up_prio_=up_prio,8,*",
      "CDEF:up_dfl_=up_dfl,8,*",
      "--interlaced",
      "--watermark=SequreISP",
      "--lower-limit=0",
      "--x-grid", xgrid,
      "--alt-y-grid",
      "--width", "#{width}",
      "--height", "#{height}",
      "--imgformat", "PNG"
    ]
  end
  def graph(time, xgrid, width, height)
    gname = "#{element.class.to_s}.#{element.id}.#{time}.#{width}.#{height}"
    rrd_args = rrd_default_args(gname, time, xgrid, width, height) + rrd_args_for_element
    alt = "No disponible" unless rrd_graph(rrd_args)
    "<img alt=\"#{alt}\" src=\"/images/rrd/#{gname}.png\">"
    #"<a href=\"/graphs/#{element.id}/?class=#{element.class.to_s}\"><img src=\"/images/rrd/#{gname}.png\"></a>"
  end
  def graph_small(time, xgrid, width, height)
    gname = "#{element.class.to_s}.#{element.id}.#{time}.#{width}.#{height}"
    rrd_args = rrd_default_args(gname, time, xgrid, width, height) + [ "--no-legend" ] + rrd_args_for_element
    alt = "No disponible" unless rrd_graph(rrd_args)
    "<img alt=\"#{alt}\" src=\"/images/rrd/#{gname}.png\">"
  end
end
