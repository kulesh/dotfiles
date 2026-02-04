## Project Overview
This is a Ruby project managed with:

- **mise-en-place** for Ruby version management
- **Bundler** for gem dependencies
- **RSpec** for testing
- **RuboCop** for linting and formatting

## Key Commands

### Development

```bash
# Run the project executable
./bin/<project_name>
```

### Testing

```bash
# Run all specs
bundle exec rspec

# Run a specific spec file
bundle exec rspec spec/<project_name>_spec.rb
```

### Code Quality

```bash
# Lint with RuboCop
bundle exec rubocop

# Auto-correct safe issues
bundle exec rubocop -A
```

### Dependencies

```bash
# Install gems
bundle install

# Add a gem (edit Gemfile, then)
bundle install

# Update gems
bundle update
```

## Project Structure

```
lib/
└── <project_name>.rb

bin/
└── <project_name>

spec/
└── <project_name>_spec.rb

Gemfile
```

## Development Guidelines

- The module name is the capitalized project name (e.g., `my_app` -> `MyApp`).
- Keep library code under `lib/` and entrypoints under `bin/`.
- Use `bundle exec` for running tooling in the project context.
