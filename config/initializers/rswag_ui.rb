# config/initializers/rswag_ui.rb
Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "API V1 Docs"
  c.config_object[:persistAuthorization] = true
end
