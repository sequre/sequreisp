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

  def contract_rate_graph(obj)
    date_keys = $redis.keys("contract_#{obj.id}_sample_*").sort

    graph = { :title => 'BuenasBuenas',
      :type => 'area',
      :render_to => 'instant',
      :stacking => 'normal',
      :ytitle => 'bps(bits/second)',
      :series => [] }

    ContractSample.compact_keys.each do |rkey|
      data = []
      times = []
      date_keys.each do |key|
        data << $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i
        data << $redis.hget("#{key}", "time").to_i
      end
      graph[:series] << { :name => rkey[:name], :type=> "up", :stack => 1, :data => data*-1 } if rkey[:name].include? "up"
      graph[:series] << { :name => rkey[:name], :type=> "down", :stack => 0, :data => data } if rkey[:name].include? "down"
    end

    { :instant => default_options_graphs(graph) }
  end

  def contract_rate_graph_for_periods(obj)
    graphs = []
    samples_by_period = ContractSample.all(:conditions => { :contract_id => obj.id} ).group_by(&:period)
    samples_by_period.each do |period, samples|
      foo = { :title => "Samples for period #{period}",
        :render_to => "contract_rate_period_#{period}",
        :ytitle => "bps(bits/second)",
        :series => [] }

      ContractSample.compact_keys.each do |rkey|
        data = []
        period_samples.each { |pp| data << pp[rkey[:name].to_sym] }

        foo[:series] << { :name => rkey[:name], :type=> "line", :stack => 1, :data => data } if rkey[:name].include? "up"
        foo[:series] << { :name => rkey[:name], :type=> "area", :stack => 0, :data => data } if rkey[:name].include? "down"
      end
      graphs << foo
    end
    graphs
  end
end
