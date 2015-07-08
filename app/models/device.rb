class Device < ActiveRecord::Base
  KIND_CPE = "cpe"
  KIND_AP = "ap"
  KIND_SWITCH = "switch"
  KIND_SERVER = "server"
  KIND_ROUTER = "router"
  named_scope :aps, :conditions => "kind = KIND_AP"
  named_scope :need_update, lambda {  { :conditions => ["updated_at <= ?", 5.minutes.ago]} }
  validates_presence_of :host, :kind, :brand
  validates_uniqueness_of :host
  # validates_format_of :mac_address, :with => /^([0-9A-Fa-f]{2}\:){5}[0-9A-Fa-f]{2}$/, :allow_blank => true
  belongs_to :device
  belongs_to :contract
  belongs_to :device_brand
end
