## A Project
A project is a self-contained development environment that contains all source code, documentation, dependencies, and other artifacts. A project's environment and dependencies are managed by mise-en-place (`mise`).

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
