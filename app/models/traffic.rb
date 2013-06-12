class Traffic < ActiveRecord::Base

  belongs_to :contract

  before_update :accumulate_data_total_extra

  named_scope :currents, :conditions => ["from_date <= ? and to_date >= ?", Date.today, Date.today]

  named_scope :for_date, lambda {|date| { :conditions => ["from_date >= ?", date]}}

  named_scope :for_contract, lambda {|id| { :conditions => (["contract_id = ?", id])}}

  def accumulate_data_total_extra
    self.data_total_extra +=  self.data_total_extra_was
  end

end
