require_dependency 'hooks_helper'
unless ActionView::Base.include?(HooksHelper)
  ActionView::Base.send :include, HooksHelper
end
