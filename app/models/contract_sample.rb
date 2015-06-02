class ContractSample < ActiveRecord::Base
  # named_scope :total_accumulated_for_period, lambda{ |period| { :select => 'SUM(contract_samples.down_prio1) as total_down_prio1,
  #                                                                           SUM(contract_samples.down_prio2) as total_down_prio2,
  #                                                                           SUM(contract_samples.down_prio3) as total_down_prio3,
  #                                                                           SUM(contract_samples.down_supercache) as total_down_supercache,
  #                                                                           SUM(contract_samples.up_prio1) as total_up_prio1,
  #                                                                           SUM(contract_samples.up_prio2) as total_up_prio2,
  #                                                                           SUM(contract_samples.up_prio3) as total_up_prio3,
  #                                                                           COUNT(*) as total,
  #                                                                           contract_samples.*',
  #                                                               :conditions => "contract_samples.period = #{period}",
  #                                                               :group  => 'contract_id' } }

  named_scope :total_for_period, lambda{ |period| { :select => 'COUNT(*) as total_samples,
                                                                contract_samples.*',
                                                    :conditions => "contract_samples.period = #{period}",
                                                    :group  => 'contract_id' } }
end
