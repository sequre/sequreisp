class ContractSample < ActiveRecord::Base
  belongs_to :contract

  named_scope :last_sample, lambda{ |period| { :select => 'COUNT(*) as total_samples, contract_samples.*',
                                               :include => 'contract',
                                               :group  => 'contract_id',
                                               :conditions => "contract_samples.sample_number IN (SELECT MAX(contract_samples.sample_number)
                                                                                                  FROM contract_samples
                                                                                                  WHERE contract_samples.period = #{period}
                                                                                                  GROUP BY contract_samples.contract_id)" } }

  named_scope :total_samples_for_period, lambda { |period| { :select => 'COUNT(*) as total_samples, contract_samples.*',
                                                             :group => 'contract_id',
                                                             :conditions => "contract_samples.period = #{period}" } }

  named_scope :samples_to_compact, lambda { |id, period, limit| { :conditions => "contract_samples.contract_id = #{id} and contract_samples.period = #{period}",
                                                                  :limit => limit } }

  def self.sample_conf
    # PERIOD    AMPLITUD              TIME_SAMPLE           SAMPLES_SIZE   SAMPLES_SIZE_SATURA
    #   0       180.min (3.hours)        1.min                  180        180 + 5 = 185
    #   1      1440.min (1.day)          5.min                  288        288 + 6 = 294
    #   2     10080.min (1.week)        30.min                  336        336 + 6 = 342
    #   3     44640.min (1.month)      180.min (3.hours)        348        348 + 8 = 356
    #   4    525600.min (1.year)      1440.min (24.hours)       365        365

    conf = { :period_0 => { :period_number => 0, :time_sample => 1,    :sample_size => 180, :sample_size_cut => 185, :excess_count => 5,   :scope => 180.minutes    },
             :period_1 => { :period_number => 1, :time_sample => 5,    :sample_size => 288, :sample_size_cut => 294, :excess_count => 6,   :scope => 1440.minutes   },
             :period_2 => { :period_number => 2, :time_sample => 30,   :sample_size => 336, :sample_size_cut => 342, :excess_count => 6,   :scope => 10080.minutes  },
             :period_3 => { :period_number => 3, :time_sample => 180,  :sample_size => 348, :sample_size_cut => 356, :excess_count => 8,   :scope => 44640.minutes  },
             :period_4 => { :period_number => 4, :time_sample => 1440, :sample_size => 348, :sample_size_cut => nil, :excess_count => nil, :scope => 525600.minutes } }

    ContractSample.transaction {
      conf.each_key do |key|
        conf[key][:samples] = {}
        conf[key][:excess_samples] = {}
        total = ContractSample.total_samples_for_period(conf[key][:period_number])

        ContractSample.last_sample(conf[key][:period_number]).each do |contract_sample|
          conf[key][:samples][contract_sample.contract_id.to_s] = contract_sample
          conf[key][:samples][contract_sample.contract_id.to_s].total_samples = total.select{|k| k.contract_id == contract_sample.contract_id }.first.total_samples
          conf[key][:excess_samples][contract_sample.contract_id.to_s] = ContractSample.samples_to_compact(contract_sample.contract_id, conf[key][:period_number], conf[key][:excess_count] )
        end
      end
    }
    conf
  end

  def self.compact(samples)
    new_sample = {}
    compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] = 0 }
    samples.each do |destroy_sample|
      compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] += destroy_sample[rkey[:name]] }
    end
    new_sample
  end

  # this has an alias_method_chain
  def self.compact_keys
    keys = []
    ["up", "down"].each do |prefix|
      ["prio1", "prio2", "prio3"].each { |k| keys << { :sample => k, :up_or_down => prefix, :name => "#{prefix}_#{k}" } }
    end
    keys
  end

  def object
    contract
  end
end
