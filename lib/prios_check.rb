module PriosCheck
  FILE_SERVICES = RAILS_ROOT + "/db/files/valid_services"
  FILE_PROTOCOLS = RAILS_ROOT + "/db/files/valid_protocols"
  FILE_HELPERS = RAILS_ROOT + "/db/files/valid_helpers"
  def validate_in_range_or_in_file(attr, min, max, type)
    if self[attr].present?
      file = case type
      when :service
        FILE_SERVICES
      when :protocol
        FILE_PROTOCOLS
      when :helper
        FILE_HELPERS
      end
      valid_services= IO.readlines(file).collect{ |i| i.chomp } rescue []
      invalid_values = []
      self[attr].split(/,|:/).each do |i|
        is_integer = Integer(i) rescue false
        unless (is_integer and i.to_i > min and i.to_i < max) or valid_services.include?(i)
          invalid_values << i
        end
      end
      if not invalid_values.empty? 
        errors.add(attr, I18n.t('validations.contract.in_range_or_in_file_invalid', :invalid_values => invalid_values.join(",")))
      end
    end
  end
end
