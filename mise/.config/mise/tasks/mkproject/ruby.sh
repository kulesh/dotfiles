#!/usr/bin/env zsh
#MISE description="Setup Ruby project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:ruby"]

source "${0:a:h}/_shared/template_helpers.sh"

echo "Setting up Ruby project..."

# Copy Ruby-specific static files (if any)
copy_template_files "ruby" "Ruby"

# Get the Ruby version from mise
RUBY_VERSION=$(mise exec -- ruby -e "puts RUBY_VERSION")
PROJECT_NAME=$(basename "$PWD")
# Capitalize first letter (zsh-compatible)
PROJECT_CLASS_NAME="${(C)PROJECT_NAME}"

# Create Ruby project structure
mkdir -p lib spec bin

# Create Gemfile with latest gem versions
cat > Gemfile << EOF
source 'https://rubygems.org'

ruby '$RUBY_VERSION'

group :development, :test do
  gem 'rspec'
  gem 'rubocop'
  gem 'pry'
end
EOF

# Create a basic Ruby file
cat > "lib/${PROJECT_NAME}.rb" << EOF
# frozen_string_literal: true

module $PROJECT_CLASS_NAME
  VERSION = '0.1.0'
end
EOF

# Create executable script
cat > "bin/${PROJECT_NAME}" << EOF
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/${PROJECT_NAME}'

puts "Hello from $PROJECT_CLASS_NAME!"
EOF

chmod +x "bin/${PROJECT_NAME}"

# Install gems and setup RSpec
mise exec -- gem install bundler
mise exec -- bundle install
mise exec -- rspec --init

# Create basic spec
cat > "spec/${PROJECT_NAME}_spec.rb" << EOF
# frozen_string_literal: true

require_relative '../lib/${PROJECT_NAME}'

RSpec.describe $PROJECT_CLASS_NAME do
  it 'has a version number' do
    expect($PROJECT_CLASS_NAME::VERSION).not_to be nil
  end
end
EOF

echo "Ruby project setup complete!"
echo "Try: bundle exec rspec"
echo "Try: ./bin/${PROJECT_NAME}"
