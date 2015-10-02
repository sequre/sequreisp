class InterfaceSample < ActiveRecord::Base
  belongs_to :interface

  # PERIOD    AMPLITUD              TIME_SAMPLE           SAMPLES_SIZE   SAMPLES_SIZE_SATURA
  #   0       180.min (3.hours)        1.min                  180        180 + 5 = 185
  #   1      1440.min (1.day)          5.min                  288        288 + 6 = 294
  #   2     10080.min (1.week)        30.min                  336        336 + 6 = 342
  #   3     44640.min (1.month)      180.min (3.hours)        348        348 + 8 = 356
  #   4    525600.min (1.year)      1440.min (24.hours)       365        365

  CONF_PERIODS = { :period_0 => { :period_number => 0, :time_sample => 1.minutes,    :sample_size => 180, :sample_size_cut => 185, :excess_count => 5,   :scope => 180.minutes    },
                   :period_1 => { :period_number => 1, :time_sample => 5.minutes,    :sample_size => 288, :sample_size_cut => 294, :excess_count => 6,   :scope => 1440.minutes   },
                   :period_2 => { :period_number => 2, :time_sample => 30.minutes,   :sample_size => 336, :sample_size_cut => 342, :excess_count => 6,   :scope => 10080.minutes  },
                   :period_3 => { :period_number => 3, :time_sample => 180.minutes,  :sample_size => 348, :sample_size_cut => 356, :excess_count => 8,   :scope => 44640.minutes  },
                   :period_4 => { :period_number => 4, :time_sample => 1440.minutes, :sample_size => 365, :sample_size_cut => nil, :excess_count => nil, :scope => 525600.minutes } }


  named_scope :for_period, lambda { |period| {:conditions => "interface_samples.period = #{period}"} }


  named_scope :total_samples_for_period, :select => 'COUNT(*) as total_samples, interface_samples.*',
                                         :group  => 'interface_id'

  named_scope :samples_to_compact, lambda { |id,limit| { :conditions => "interface_samples.interface_id = #{id}",
                                                         :limit => limit } }

  named_scope :get_new_samples, lambda { |period| { :order => "sample_number DESC",
                                                    :conditions => "interface_samples.sample_number = (SELECT MAX(sample_number)
                                                                                                      FROM interface_samples as foo
                                                                                                      WHERE interface_samples.period = #{period} AND
                                                                                                            interface_samples.interface_id = foo.interface_id
                                                                                                      ORDER BY sample_number LIMIT 1) AND
                                                                    interface_samples.period = #{period}" }}

  def self.last_samples_created
    samples = {}
    InterfaceSample.transaction {
      CONF_PERIODS.count.times do |i|
        samples["period_#{i}".to_sym] = Hash[InterfaceSample.get_new_samples(i).collect{ |i| [i.interface_id, i.sample_number.to_i] }]
      end
    }
    samples
  end

  def self.samples_to_compact
    samples_to_compact = {}
    InterfaceSample.transaction {
      CONF_PERIODS.count.times do |period|
        samples_to_compact["period_#{period}".to_sym] = {}
        unless CONF_PERIODS["period_#{period}".to_sym][:excess_count].nil?
          InterfaceSample.for_period(CONF_PERIODS["period_#{period}".to_sym][:period_number]).total_samples_for_period.all.each do |is|
            if is.total_samples.to_i >= CONF_PERIODS["period_#{period}".to_sym][:sample_size_cut]
              samples_to_compact["period_#{period}".to_sym][is.interface_id] = InterfaceSample.for_period(CONF_PERIODS["period_#{period}".to_sym][:period_number]).samples_to_compact(is.interface_id, (is.total_samples.to_i - CONF_PERIODS["period_#{period}".to_sym][:sample_size])).all
            end
          end
        end
      end
    }
    samples_to_compact
  end

  def self.compact(period, samples)
    time = CONF_PERIODS["period_#{period}".to_sym][:scope]
    new_sample = {}
    compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] = 0 }
    samples.each do |destroy_sample|
      compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] += (destroy_sample[rkey[:name]] / time )}
    end
    new_sample
  end

  # this has an alias_method_chain
  def self.compact_keys
    keys = []
    ["rx", "tx"].each do |prefix|
      keys << {:name => "#{prefix}" }
    end
    keys
  end


  def object
    interface
  end
end
