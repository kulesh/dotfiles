# CLAUDE.md

This file provides guidance to Claude Code when working with code in this project.

## First Things First

BEFORE ANYTHING ELSE: run 'bd onboard' and follow the instructions

## Project Overview

This is a basic project managed with mise-en-place for development environment and dependencies.

## Key Commands

### Development Environment

```bash
# Show mise configuration and installed tools
mise ls

# Install dependencies defined in .mise.toml
mise install

# Run project tasks (if defined)
mise tasks ls
mise run <task_name>
```

### Git Workflow

```bash
# Check status
git status

# Create a branch
git checkout -b feature/your-feature-name

# Commit changes
git add .
git commit -m "Your commit message"

# Push changes
git push origin <branch-name>
```

## Project Structure

This project follows standard conventions:

- `README.md` - Project documentation
- `.gitignore` - Files to exclude from git
- `.mise.toml` - Development environment configuration

## Development Guidelines

### Code Quality

- Write clear, descriptive commit messages
- Keep commits focused and atomic
- Document significant changes in README.md

### Dependencies

- Use mise to manage project-specific tools and runtimes
- Document any system dependencies in README.md

## Notes for Claude Code

- This is a base project template - specific implementations will vary
- Check for additional configuration files (like language-specific configs)
- Respect existing code style and patterns
- When adding dependencies, update both .mise.toml and documentation
