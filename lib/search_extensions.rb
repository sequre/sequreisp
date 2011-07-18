ActiveSupport::Dependencies.load_once_paths << File.dirname(__FILE__)

module SearchExtensions
  SEARCH_FORM_PARTIALS_PATH = 'search_form'.freeze
  @extensions ||= {}

  class << self
    attr_accessor :extensions
  end

  def self.add(partial, options)
    normalize_options(options)
    options[:controller].each do |controller|
      @extensions[controller] ||= []
      @extensions[controller] << partial
    end
  end

  def render_search_extensions(locals={})
    ret = ""
    controller = self.controller.controller_name.to_sym
    SearchExtensions.extensions[controller].each do |partial|
      partial = "#{controller}/#{SEARCH_FORM_PARTIALS_PATH}/#{partial}"
      ret += render :partial => partial, :locals => locals
    end
    ret
  end

  private

  def self.normalize_options(options)
    case options[:controller]
      when Symbol, String
        options[:controller] = [options[:controller].to_sym]
      when Array
        options[:controller].map do |c| c.to_sym end
      else
        raise "Array, Symbol or String expected, #{options[:controller].class} received"
    end
  end

  def self.autoload_search_form_extensions
    paths = []
    ActionController::Base.view_paths.each do |path|
      paths += Dir.glob(path.to_s + "/*/#{SEARCH_FORM_PARTIALS_PATH}")
    end

    paths.each do |path|
      controller = path.split('/')[-2]
      Dir.glob(path += '/*').each do |file|
        partial = file.split('/')[-1].sub(/\A_/, '').sub(/\.html\.erb\z/, '')
        @extensions[controller.to_sym] ||= []
        @extensions[controller.to_sym] << partial
      end
    end
  end
end
