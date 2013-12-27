Dir.glob(Rails.root.join 'vendor/plugins/sequreisp_<%= name.downcase %>/lib/<%= name.downcase %>_patches/*').each do |path|
  require path
end
