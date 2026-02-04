## Project Overview
This is a Python project managed with:

- **mise-en-place** for Python version management
- **uv** for fast Python package management
- **pyproject.toml** for project metadata and dependencies
- **pytest** for testing
- **ruff** (linting + formatting) and **mypy** for code quality

## Key Commands

### Development

```bash
# Run the project entry point
uv run <project_name>
```

### Testing

```bash
# Run all tests
uv run pytest

# Run a specific test file
uv run pytest tests/test_<module_name>.py

# Run tests with coverage
uv run pytest --cov=src/<module_name> --cov-report=term-missing
```

### Code Quality

```bash
# Format code with ruff
uv run ruff format src/ tests/

# Lint with ruff
uv run ruff check src/ tests/

# Type check with mypy
uv run mypy src/
```

### Dependencies

```bash
# Add a package
uv add <package_name>

# Add a dev dependency
uv add --dev <package_name>

# Sync dependencies
uv sync

# Update all dependencies
uv lock --upgrade
uv sync
```

## Project Structure

```
src/<module_name>/
├── __init__.py
└── main.py

tests/
└── test_<module_name>.py

pyproject.toml
```

## Development Guidelines

- Keep runtime code under `src/<module_name>/`.
- Keep tests in `tests/` and prefer pytest fixtures.
- Use `uv` for all dependency changes.
- Update `pyproject.toml` whenever dependencies change.
