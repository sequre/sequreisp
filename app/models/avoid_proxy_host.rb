class AvoidProxyHost < ActiveRecord::Base
  acts_as_audited
  validates_presence_of :name
  validates_format_of :name, :with => /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?)*\.?$/

  include ModelsWatcher
  watch_fields :name
  watch_on_destroy

  def ip_addresses
    require 'resolv'
    begin
      Resolv.getaddresses(name).select do |a| IP.new(a).is_a?(IP::V4) end
    rescue
      []
    end
  end

  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
end
