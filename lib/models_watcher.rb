module ModelsWatcher

  def self.included(base)
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
    base.class_eval do
      before_save :check_watched_fields
    end
  end

  module ClassMethods

    def watch_fields(*fields)
      define_method :check_watched_fields do
        fields.each do |field|
          if self.send "#{field}_changed?"
            update_changes_to_apply
          end
        end
      end
    end

    def watch_on_destroy
      after_destroy :update_changes_to_apply
    end

  end

  module InstanceMethods
    def update_changes_to_apply
      Configuration.first.update_attribute(:changes_to_apply, true)
    end
  end

end
