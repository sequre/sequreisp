source "http://rubygems.org"
source "http://gems.github.com"
gem 'rails', '=2.3.11'

gem 'mysql'
gem 'formtastic', '~>1.2'
gem 'authlogic', '=2.1.6'
gem 'rubyist-aasm', '=2.1.1', :require => 'aasm'
gem 'searchlogic', '~> 2.4.0'
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
gem 'RedCloth'
gem "context_help"

group :development, :test do
  gem 'faker'
  gem 'rspec-rails', '1.3.3'
  gem 'guard-rspec'
  group :linux do
    gem 'rb-inotify'
    gem 'libnotify'
  end
end

group :development do
  gem 'ruby-debug'
  gem 'annotate'
end

group :test do
  gem 'factory_girl'
  gem 'shoulda-context'
end
# Hack to install gems from each plugin, c&p from 
# http://madebynathan.com/2010/10/19/how-to-use-bundler-with-plugins-extensions/
Dir.glob(File.join(File.dirname(__FILE__), 'vendor', 'plugins', '**', "Gemfile")) do |gemfile|
    self.send(:eval, File.open(gemfile, 'r').read)
end

