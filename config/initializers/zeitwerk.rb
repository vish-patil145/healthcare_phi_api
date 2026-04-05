Rails.autoloaders.each do |autoloader|
  autoloader.ignore(Rails.root.join("app/middleware"))
end
