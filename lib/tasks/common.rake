namespace :db do
  desc 'Run migrations from start'
  task :remigrate => :environment do
    ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.drop_table t }
    # Migrate upward
    Rake::Task["db:migrate"].invoke
    # Dump the schema
    Rake::Task["db:schema:dump"].invoke
  end

  desc 'Remigrate and seed'
  task :reseed => [:remigrate, :seed]

  desc 'Remigrate and seed'
  task :repopulate => [:remigrate, :seed, 'populate:all']

  desc 'Reset, populate and simulate'
  task :resimulate => [:reset, 'populate:all', :simulate]
end
