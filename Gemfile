source "http://rubygems.org"
source "http://gems.github.com"
gem 'rails', '=2.3.11'
gem 'rdoc', '=4.0.1'
gem 'mysql', '=2.9.1'
gem 'formtastic', '=1.2.5'
gem 'authlogic', '=2.1.6'
gem 'rubyist-aasm', '=2.1.1', :require => 'aasm'
gem 'searchlogic', '=2.5.6'
gem 'will_paginate', '=2.3.16'
gem 'rrd-ffi', '=0.2.14', :require => 'rrd'
gem 'ruby-ip', '=0.9.1', :require => 'ip'
gem 'ar-extensions', '=0.9.5'
gem 'thoughtbot-paperclip', '=2.3.1', :require => 'paperclip'
gem 'daemons', '=1.1.0'
gem 'fastercsv', '=1.5.5'
gem 'aegis', '=2.5.3'
gem 'acts_as_audited', '=1.1.1'
gem 'RedCloth', '=4.2.9'
gem "context_help", '=0.0.9'
gem 'open4', '=1.3.3'
gem 'redis', '=3.2.1'

group :development, :test do
   gem 'faker', '=1.0.1'
   gem 'rspec-rails', '=1.3.3'
  group :linux do
     gem 'rb-inotify', '=0.9.0'
     gem 'libnotify', '=0.8.0'
  end
end

group :development do
   gem 'ruby-debug', '=0.10.4'
   gem 'annotate', '=2.5.0'
   gem 'wirble', '=0.1.3'
end

group :test do
   gem 'factory_girl', '=2.6.4'
   gem 'shoulda-context', '=1.1.1'
end
# Hack to install gems from each plugin, c&p from
# http://madebynathan.com/2010/10/19/how-to-use-bundler-with-plugins-extensions/
Dir.glob(File.join(File.dirname(__FILE__), 'vendor', 'plugins', '**', "Gemfile")) do |gemfile|
    self.send(:eval, File.open(gemfile, 'r').read)
end
