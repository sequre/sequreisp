ContextHelp::Base.config[:show_missing] = false
ContextHelp::Base.config[:text_tag] = 'div'
ContextHelp::Base.config[:link_to_object] = true
ContextHelp::Base.config[:link_to_help] = true
ContextHelp::Base.config[:link_to_help_builder] = lambda do |options|
  return '' if not ContextHelp::Helpers.is_visible(options) and not ContextHelp::Base.config[:show_missing]
  title = ContextHelp::Helpers.get_title(options)
  if title and options[:link_to_help] and !options[:link_to_help_shown]
    options[:link_to_help_shown] = true
    "<a href=\"#\" onclick=\"context_help_link_to_help(this, '##{options[:item_id]}'); return false;\" id=\"#{options[:item_id]}_object\" class=\"context_help_link_to_help\"><span class=\"ui-icon ui-icon-help\" style=\"display: inline-block\"></span></a>"
  else
    ''
  end
end
ContextHelp::Base.config[:link_to_object_builder] = lambda do |options|
  return '' if not ContextHelp::Helpers.is_visible(options) and not ContextHelp::Base.config[:show_missing]
  title = ContextHelp::Helpers.get_title(options)
  if options[:link_to_object]
    "<a href=\"#\" onclick=\"context_help_link_to_object(this, '##{options[:item_id]}_object'); return false;\">#{title}</a>"
  else
    title
  end
end
ContextHelp::Base.config[:inline_help_builder] = lambda do |options|
  if options[:show_inline]
    ContextHelp::Base.html_help(options)
  elsif options[:link_to_help] and [:label, :th].include?(options[:path][:tag])
    ContextHelp::Base.link_to_help(options)
  else
    ''
  end
end
ContextHelp::Base.config[:help_builder] = lambda do |options|
  return '' if not ContextHelp::Helpers.is_visible(options) and not ContextHelp::Base.config[:show_missing]
  text = RedCloth.new(ContextHelp::Helpers.get_text(options)).to_html
  "<#{options[:title_tag]} id=\"#{options[:item_id]}\" class=\"#{options[:title_class]} #{options[:level_class]}\">#{ContextHelp::Base.link_to_object(options)}</#{options[:title_tag]}>
  <#{options[:text_tag]} class=\"#{options[:text_class]} #{options[:level_class]}\">#{text}</#{options[:text_tag]}>"
end

module ContextHelp
end

=begin
ContextHelp customization:

Puede definirse parámetros globales cambiando los siguientes valores en ContextHelp::Base::config
  ContextHelp::Base::config
    :show_inline      (boolean)   Indica si se mostrará la ayuda junto con el elemento.
    :title_tag        (string)    Indica el nombre de la etiqueta HTML utilizada para los títulos.
    :title_class      (string)    Clase CSS utilizada en el título
    :text_tag         (string)    Indica el nombre de la etiqueta HTML utilizada para los textos
    :text_class       (string)    Clase CSS utilizada en el texto

    :level_classes    (hash)      Pueden definirse clases CSS que se aplican a las etiquetas de ayuda
                                dependiendo del tipo de elemento que se ha detectado

     :model           (string)    Clase CSS para ayuda de modelos
     :model_attribute (string)    Clase CSS para ayuda de atributos

     :html            (hash)      Clases CSS por tipo de etiqueta HTML
       :default       (string)    Clase CSS para una etiqueta por defecto
       :form          (string)    Clase CSS para etiquetas form
       ....

     :custom          (string)    Clase CSS para elementos de ayuda con path = custom

   :exclude_tags      (Array)     Listado de etiquetas que no se detectarán
   :exclude_models    (Array)     Listado de modelos que se ignorarán en la detección
   :show_missing      (boolean)   Indica si en modo development debe mostrar aquellos elementos que no tienen
                                  documentación escrita.

   :link_to_object    (boolean)   Incluir link al objeto que tiene ayuda
   :link_to_help      (boolean)   Incluir link a la ayuda del objeto


   :link_to_object_builder  (proc)  Método que devuelve el HTML del link al objeto.
   :link_to_help_builder    (proc)  Método que devuelve el HTML del link a la ayuda.
   :help_builder            (proc)  Método que devuelve el HTML de ayuda para un elemento dado.
   :inline_help_builder     (proc)  Método que devuelve el HTML de ayuda para un elemento dado.
   
Pueden pasarse parámetros en los elementos de formtastic o form_for... para sobreescribir la opciones
por defecto. Los mismos deben pasarse dentro de un parámetro llamado :context_help

  form.input :title, :context_help => {
    :path => (Hash) indica la ruta al elemento de ayuda
      :model => (string) nombre del modelo
      :attribute => (string) nombre del atributo. Si este parámetro se pasa, debe pasarse también :model
      :tag => nombre de etiqueta HTML
      :custom => ruta a elemento en el archivo YAML bajo context_help.custom.
    
    :level_class => Clase a aplicar
    :skip => (boolean) ignorar ayuda
    :show_inline => mostrar inline
    :link_to_object
    :link_to_help
    :title_tag
    :title_class
    :text_tag
    :text_class
    :title  (string) forzar el uso de un titulo personalizado
    :text  (string) forzar el uso de un titulo personalizado
}
  
También puede mostrarse ayuda o insertar el registro dentro del flujo del documento con
  ContextHelp::Base.help_for(options)
Donde options es un hash con un elemento :context_help y los parámetros definidos anteriormente
=end
