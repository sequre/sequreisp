module SequreispConfig
  # load de files de configuración
  CONFIG = YAML::load(File.open("#{RAILS_ROOT}/config/sequreisp_config_#{Rails.env}.yml"))
end
