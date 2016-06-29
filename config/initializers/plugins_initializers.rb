Dir.glob(File.join(Rails.root, 'vendor', 'plugins', '**', 'config', 'initializers', '*')) do |initializer|
    self.send(:eval, File.open(initializer, 'r').read)
end
Dir.glob(File.join(Rails.root, 'vendor', 'plugins', '**', 'db', 'migrate', '*')) do |path|
  require path
end
