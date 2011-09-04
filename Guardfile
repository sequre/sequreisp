# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'rspec', :version => 1, :spec_paths => ['spec', 'vendor/plugins'], :cli => '--color' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec/" }

  # Rails example
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec/" }
  watch('spec/spec_helper.rb')                        { "spec/" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  # Capybara request specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }

  # Plugins
  watch(%r{^vendor/plugins/(.+)/spec/spec_helper\.rb$})         {  |m| "vendor/plugins/# { m[1]}/spec/" }
  watch(%r{^vendor/plugins/(.+)/spec/.+_spec\.rb$})
  watch(%r{^vendor/plugins/(.+)/app/(.+)\.rb$})                 {  |m| "vendor/plugins/# { m[1]}/spec/#        { m[2]}_spec.rb" }
  watch(%r{^vendor/plugins/(.+)/lib/.+patches/(.+)_patch\.rb$}) {  |m| "vendor/plugins/# { m[1]}/spec/models/# { m[2]}_spec.rb" }

end

