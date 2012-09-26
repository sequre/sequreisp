module IpAddressCheck

  def self.included(base)
    return if base.include? InstanceMethods

    base.send(:include, InstanceMethods)
    base.send(:extend, ClassMethods)

    base.class_eval do
      @__ip_fields ||= []
      validate :check_ip_fields
    end
  end
  module ClassMethods
    def validate_ip_format_of(*args)
      options = args.extract_options!
      @__ip_fields += args
      args.each do |f|
        unless options[:with_netmask]
          validates_format_of f, :with => /^([12]{0,1}[0-9]{0,1}[0-9]{1}\.){3}[12]{0,1}[0-9]{0,1}[0-9]{1}$/, :allow_blank => true
        end
      end
    end
  end

  module InstanceMethods
    def  check_ip_fields
      fields = self.class.instance_eval do @__ip_fields end
      fields.each do |f|
        next if self[f].blank?
        begin
          ip = IP.new self[f]
          self[f] = ip.to_s
        rescue
          errors.add f, I18n.t("validations.ip_is_not_valid")
        end
      end
    end
  end
end
