class AvoidBalancingHost < ActiveRecord::Base
  belongs_to :provider
  acts_as_audited
  validates_presence_of :name, :provider
  validates_format_of :name, :with => /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?)*\.?$/

  include ModelsWatcher
  watch_fields :name, :provider_id
  watch_on_destroy

  def ip_addresses
    require 'resolv'

    begin
      Timeout::timeout(3) do
        Resolv::DNS.open(:nameserver => ["127.0.0.1"]) do |dns|
          dns.getaddresses(name).map(&:to_s).select { |a| IP.new(a).is_a?(IP::V4) }
        end
      end
    rescue Timeout::Error => e
      log_rescue("[Model][AvoidBalancingHost] timeout for ip_addresses #{name}", e)
      []
    rescue => e
      log_rescue("[Model][AvoidBalancingHost] ip_addresses method failed", e)
      []
    end
  end

  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
end
