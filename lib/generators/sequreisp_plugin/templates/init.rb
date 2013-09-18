#refactor
ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}

###LICENSE_TAG###if ::RGLoader::get_const('plugins') and  ::RGLoader::get_const('plugins').split(",").include?('<%= name.downcase %>')

require 'sequreisp_<%= name.downcase %>'
require 'hooks_helper'

#should be loaded only once
unless ActionView::Base.include?(HooksHelper)
  ActionView::Base.send :include, HooksHelper
end

# require_dependency 'boot_hook'
# BootHook.send :include, <%= "#{name.camelize}::BootHookPatch" %>

# require_dependency 'daemon_hook'
# DaemonHook.send :include, <%= "#{name.camelize}::DaemonHookPatch" %>


require 'dispatcher'
Dispatcher.to_prepare <%= ":#{name.downcase}" %> do
  # Example define patch for models
  # require_dependency('client')
  # Client.send :include, <%= name.camelize %>::ClientPatch
  # require_dependency('contract')
  # Contract.send :include, <%= name.camelize %>::ContractPatch
  # require_dependency('plan')
  # Plan.send :include, <%= name.camelize %>::PlanPatch
  # require_dependency('configuration')
  # ::Configuration.send :include, <%= name.camelize %>::ConfigurationPatch
end

# Example define patch for views
# ActionView::Base.send :include, <%= name.camelize %>::HelperPatch
# ActionView::Base.send :include, <%= name.camelize %>::MenuPatch
# ActionView::Base.send :include, <%= name.camelize %>::FormExtensions
# ActionView::Base.send :include, <%= name.camelize %>::TableExtensions


###LICENSE_TAG###end
