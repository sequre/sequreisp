source "http://rubygems.org"
source "http://gemcutter.org"
source "http://gems.github.com"
gem 'rails', '~> 2.3.5'

gem 'mysql'
gem 'formtastic', '~>1.2'
gem 'authlogic', '=2.1.6'
gem 'rubyist-aasm', '=2.1.1', :require => 'aasm'
gem 'searchlogic', '~>2.4'
gem 'will_paginate', '~>2.3'
gem 'rrd-ffi', '~>0.2', :require => 'rrd'
gem 'ruby-ip', '~>0.9', :require => 'ip'
gem 'ar-extensions', '~>0.9'
gem 'thoughtbot-paperclip', '~>2.3', :require => 'paperclip'
gem 'daemons', '=1.1.0'
gem 'fastercsv', '~>1.5'
gem 'aegis', '~>2.5'
gem 'acts_as_audited', '~>1.1'
gem 'whenever', '~>0.6'

group :development do
  gem 'faker'
  gem 'ruby-debug'
end
# Hack to install gems from each plugin, c&p from 
# http://madebynathan.com/2010/10/19/how-to-use-bundler-with-plugins-extensions/
Dir.glob(File.join(File.dirname(__FILE__), 'vendor', 'plugins', '**', "Gemfile")) do |gemfile|
    self.send(:eval, File.open(gemfile, 'r').read)
end

