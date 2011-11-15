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

  desc 'Same as script/runner misc/simulate-rrd.rb'
  task :simulate => :environment do
    eval(File.open('misc/simulate-rrd.rb', 'r').read)
  end

  desc 'Reset, populate and simulate'
  task :resimulate => [:reset, 'populate:all', :simulate]
end
