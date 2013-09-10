class SequreispPluginGenerator < Rails::Generator::NamedBase

  attr_reader   :controller_class_name, :class_name
  attr_accessor :attributes

  def initialize(runtime_args, runtime_options = {})
    super
    @name = runtime_args.first
    @controller_class_name = @name.pluralize.capitalize
    @attributes = []

    runtime_args[1..-1].each do |arg|
      if arg.include? ':'
        @attributes << Rails::Generator::GeneratedAttribute.new(*arg.split(":"))
      end
    end

    puts @attributes
  end

  def manifest
    record do |m|
      m.directory('vendor/plugins')
      m.directory("vendor/plugins/sequreisp_#{name.downcase}")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/app")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/app/controllers")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/app/models")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/app/views")

      m.directory("vendor/plugins/sequreisp_#{name.downcase}/config")
      m.template('routes.rb', "vendor/plugins/sequreisp_#{name.downcase}/config/routes.rb")

      m.directory("vendor/plugins/sequreisp_#{name.downcase}/config/locales")
      m.template('en.yml', "vendor/plugins/sequreisp_#{name.downcase}/config/locales/en.#{name.downcase}.yml")
      m.template('es.yml', "vendor/plugins/sequreisp_#{name.downcase}/config/locales/es.#{name.downcase}.yml")
      m.template('pt.yml', "vendor/plugins/sequreisp_#{name.downcase}/config/locales/pt.#{name.downcase}.yml")

      m.directory("vendor/plugins/sequreisp_#{name.downcase}/db")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/db/migrate")

      m.template('init.rb', "vendor/plugins/sequreisp_#{name.downcase}/init.rb")
      # m.file('install.rb', "vendor/plugins/sequreisp_#{name.downcase}/install.rb")

      m.directory("vendor/plugins/sequreisp_#{name.downcase}/lib")
      m.template("sequreisp_patch.rb", "vendor/plugins/sequreisp_#{name.downcase}/lib/sequreisp_#{name.downcase}.rb")
      m.directory("vendor/plugins/sequreisp_#{name.downcase}/lib/#{name.downcase}_patches")

      # m.directory("vendor/plugins/sequreisp_#{name.downcase}/lib/tasks")
      # m.file('MIT-LICENSE', "vendor/plugins/sequreisp_#{name.downcase}/MIT-LICENSE")
      # m.file('Rakefile', "vendor/plugins/sequreisp_#{name.downcase}/Rakefile")
      m.template('README', "vendor/plugins/sequreisp_#{name.downcase}/README")
      # m.file('uninstall.rb', "vendor/plugins/sequreisp_#{name.downcase}/uninstall.rb")
      # Do something
    end
  end

end
