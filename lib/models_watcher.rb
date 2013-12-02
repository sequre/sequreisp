module ModelsWatcher

  def self.included(base)
    # Prevent run the extend and initialization twice
    # Do I need to do this?
    return if not @__watched_fields.nil?
    base.send(:extend, ClassMethods)

    base.class_eval do
      @__watched_fields ||= []
      before_save :check_watched_fields
    end
  end

  module ClassMethods

    def watch_fields(*fields)
      @__watched_fields += [fields]
    end

    def watch_on_destroy
      after_destroy :update_changes_to_apply
    end

  end

  def check_watched_fields
    if @__skip_check_watched_fields_callback
      @__skip_check_watched_fields_callback = false
      return
    end

    fields_group = self.class.instance_eval do @__watched_fields end
    # I need to do this again, if i don't call watch_fields, fields is nil at this point
    fields_group ||= []
    fields_group.each do |fields|
      options = fields.extract_options!
      fields.each do |field|
        rule = ["#{field}_changed?"]
        rule << "#{field} == #{options[:only_on_true]}" if options[:only_on_true]
        if self.send rule.join(" and ")
          update_changes_to_apply
          break
        end
      end
    end
  end

  def update_changes_to_apply
    if Configuration.first
      Configuration.first.update_attribute(:changes_to_apply, true)
    end
  end

  def save_without_applying_changes
    @__skip_check_watched_fields_callback = true
    save
  end

end
