# spec/swagger_helper.rb
require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  # Load schemas from the handwritten swagger.yaml so $ref resolution works
  _swagger_yaml = YAML.load_file(
    Rails.root.join('swagger/v1/swagger.yaml'),
    permitted_classes: [ Symbol ],
    symbolize_names: false
  )
  _schemas = _swagger_yaml.dig('components', 'schemas')
              .transform_keys(&:to_sym)
              .transform_values { |v| JSON.parse(v.to_json, symbolize_names: true) }

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'PHI Vault API',
        version: 'v1'
      },
      servers: [ { url: 'http://localhost:3000' } ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        },
        schemas: _schemas   # ← pulled from your handwritten yaml
      }
    }
  }

  config.openapi_format = :yaml
end
