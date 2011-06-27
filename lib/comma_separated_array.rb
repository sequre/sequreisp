module CommaSeparatedArray

  def self.included(base)
    base.send(:extend, ClassMethods)
  end
  module ClassMethods
    def comma_separated_array_field(*fields)
      fields.each do |field|
        define_method field.to_s + '_array' do
          self[field].to_s.split(",")
        end
      end
    end
  end
end
