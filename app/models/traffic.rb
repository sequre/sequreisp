class Traffic < ActiveRecord::Base
  belongs_to :contract

  named_scope :currents, :conditions => ["from_date <= ? and to_date >= ?", Date.today, Date.today]

  before_update :accumulate_data_total_extra

  def accumulate_data_total_extra
    self.data_total_extra +=  self.data_total_extra_was
  end

end
