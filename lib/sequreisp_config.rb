module SequreispConfig
  # load de files de configuración
  suffix = Rails.env.production? ? 'production' : 'development'
  CONFIG = YAML::load(File.open("#{RAILS_ROOT}/config/sequreisp_config_#{suffix}.yml"))
end
