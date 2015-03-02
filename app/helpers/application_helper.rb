# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def heading text
    content_for :heading, "<h1> #{text} </h1>"
  end

  def render_new_button_for model
    if current_user.send "may_create_#{model.to_s}?"
      render :partial => "shared/create_new_button",
              :locals => { :path => self.send("new_#{model.to_s}_path")}
    end
  end

  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_fields(this)")
  end

  def link_to_add_fields(name, f, association, path="shared/")
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}", :context_help => { :path => { :model => new_object.class.name } }) do |builder|
      render(path + association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, h("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"))
  end

  def error_messages object
    errors = object.errors

    return "" if errors.empty?

    header_text = t('activerecord.errors.template.header.' + (errors.one? ? "one" : "other"),
                    {:model => object.class.human_name, :count => errors.size}
                  )

    list = []
    errors.each_error do |attr, error|
      attr_name = attr == 'base' ? "" : attr_name = t("activerecord.attributes.#{error.base.class.model_name.underscore}.#{error.attribute.to_s}")
      list << content_tag(:span, attr_name, :class => "attribute_name") + " " + error.message
    end

    list.collect! { |e| content_tag :li, e}

    content_tag(:div, :class => "errorExplanation") do
      text = content_tag(:h2, header_text)
      text << content_tag(:p, t('activerecord.errors.template.body'))
      text << content_tag(:ul, list.join)
    end
  end

  def sequreisp_guides_url
    Configuration::GUIDES_URL + (I18n.locale == :en ? "/en" : "")
  end

  def portal_url
    SequreISP::PORTAL_URL + "?locale=#{I18n.locale}"
  end

  def website_url
    SequreISP::URL + "?locale=#{I18n.locale}"
  end

  def support_url
    "http://www.wispro.co/portal/issues/new?locale=#{I18n.locale}"
  end
end
