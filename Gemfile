source "https://rubygems.org"
# Frontend / SPA bridge
gem "vite_rails"
gem "inertia_rails"

# Billing
gem "pay"
gem "stripe", "~> 15" # Pay requires stripe ~> 15

# SEO
gem "sitemap_generator"

# Social login
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "omniauth-google-oauth2"

gem "ruby_llm"
gem "kramdown"  # Markdown to HTML conversion
gem "google-ads-googleads", "~> 36.0"  # Official Google Ads API client

# Email
gem "resend"

# Env in dev/test
gem "dotenv-rails", groups: [ :development, :test ]

# Dev tools
gem "annotate", group: [ :development ]
gem "letter_opener_web", group: [ :development ]

# Hardening/lint
gem "rack-attack"
gem "rubocop-rails", group: :development

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "pry"
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Testing utilities
  gem "mocha"           # Mocking/stubbing
  gem "webmock"         # HTTP request stubbing
  gem "vcr"             # Record HTTP interactions
  gem "simplecov"       # Code coverage
  gem "shoulda-matchers" # Validation/association matchers
end
