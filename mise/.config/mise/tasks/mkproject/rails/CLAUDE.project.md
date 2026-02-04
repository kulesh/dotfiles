## Project Overview
This is a Ruby on Rails application managed with:

- **mise-en-place** for Ruby version and development tools
- **Bundler** for Ruby gem dependencies
- **Rails** web application framework

## Key Commands

### Development Server

```bash
# Start the Rails server
rails server
# or
rails s

# Start with specific port
rails server -p 3001

# Start console
rails console
# or
rails c
```

### Database

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Rollback migration
rails db:rollback

# Seed database
rails db:seed

# Reset database (drop, create, migrate, seed)
rails db:reset
```

### Testing

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/user_test.rb

# Run with coverage (if configured)
rails test
```

### Code Generation

```bash
# Generate model
rails generate model User name:string email:string

# Generate controller
rails generate controller Users index show

# Generate scaffold
rails generate scaffold Post title:string body:text

# See all generators
rails generate
```

### Dependencies

```bash
# Install gems
bundle install

# Update gems
bundle update

# Add a gem (manually edit Gemfile, then)
bundle install
```

## Project Structure

```
app/
├── controllers/    # Request handlers
├── models/        # Data models (ActiveRecord)
├── views/         # HTML templates (ERB)
├── helpers/       # View helper methods
├── mailers/       # Email logic
└── jobs/          # Background jobs

config/
├── routes.rb      # URL routing
├── database.yml   # Database configuration
└── environments/  # Environment-specific config

db/
├── migrate/       # Database migrations
└── seeds.rb       # Seed data

test/              # Test files (or spec/ for RSpec)
```

## Development Guidelines

### Rails Conventions

- Follow Rails naming conventions (Model: singular, Controller: plural)
- Use RESTful routes when possible
- Keep controllers thin, models fat
- Use concerns for shared behavior

### Database

- Always create migrations for schema changes
- Never edit old migrations that have been committed
- Write reversible migrations when possible
- Use `change` method instead of `up`/`down` when possible

### Testing

- Write tests for models, controllers, and critical business logic
- Use fixtures or factories for test data
- Test both happy paths and edge cases

### Code Quality

- Follow Ruby style guide and Rails best practices
- Use descriptive variable and method names
- Keep methods short and focused
- Add comments for complex business logic

### Dependencies

- Keep Gemfile organized by purpose
- Specify gem versions to ensure consistency
- Run `bundle update` carefully and test thoroughly

## Common Patterns

### Creating a new resource

```bash
rails generate scaffold Article title:string body:text published:boolean
rails db:migrate
```

### Adding associations

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :posts
end

# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :posts do
    resources :comments, only: [:create, :destroy]
  end
  root "posts#index"
end
```

## Notes for Claude Code

- Check `config/routes.rb` to understand application structure
- Respect MVC architecture - keep logic in appropriate layers
- Use Rails generators for consistency
- Follow existing patterns in the codebase
- When adding gems, consider security and maintenance status
- Check Rails version in Gemfile for version-specific features
