#!/usr/bin/env zsh
#MISE description="Setup Python project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:python"]

source "${0:a:h}/_shared/template_helpers.sh"

echo "Setting up Python project..."

# Copy Python-specific static files (if any)
copy_template_files "python" "Python"

PROJECT_NAME=$(basename "$PWD")
# Convert to valid Python module name (replace hyphens with underscores)
MODULE_NAME="${PROJECT_NAME//-/_}"

# Get Python version from mise
PYTHON_VERSION=$(mise exec -- python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

# Create proper Python project structure
mkdir -p src/$MODULE_NAME tests

# Create pyproject.toml first
cat > "pyproject.toml" << EOF
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$PROJECT_NAME"
version = "0.1.0"
description = "A Python project"
requires-python = ">= $PYTHON_VERSION"
dependencies = []

[project.optional-dependencies]
dev = [
    "pytest",
    "pytest-cov",
    "ruff",
    "mypy"
]

[project.scripts]
$PROJECT_NAME = "$MODULE_NAME:main"

[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "W"]

[tool.mypy]
python_version = "$PYTHON_VERSION"
strict = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=src/$MODULE_NAME --cov-report=term-missing"
pythonpath = ["src"]
EOF

# Create package __init__.py with public API
cat > "src/$MODULE_NAME/__init__.py" << EOF
"""$PROJECT_NAME - A Python project."""

from .main import hello, main

__version__ = "0.1.0"
__all__ = ["hello", "main"]
EOF

# Create main module
cat > "src/$MODULE_NAME/main.py" << EOF
"""Main module for $PROJECT_NAME."""


def hello(name: str = "World") -> str:
    """Return a greeting message."""
    return f"Hello, {name}!"


def main() -> None:
    """Entry point for the application."""
    print(hello())


if __name__ == "__main__":
    main()
EOF

# Create idiomatic test file
cat > "tests/test_$MODULE_NAME.py" << EOF
"""Tests for $MODULE_NAME."""

import pytest
from $MODULE_NAME import hello, main


def test_hello_default():
    """Test hello with default argument."""
    assert hello() == "Hello, World!"


def test_hello_custom():
    """Test hello with custom name."""
    assert hello("Python") == "Hello, Python!"


def test_main(capsys):
    """Test main function output."""
    main()
    captured = capsys.readouterr()
    assert "Hello, World!" in captured.out
EOF

# Install development dependencies and package in editable mode
mise exec -- uv add --dev pytest pytest-cov ruff mypy
mise exec -- uv pip install -e .
mise exec -- uv sync

echo "Python project setup complete!"
echo "Try: uv run pytest"
echo "Try: uv run $PROJECT_NAME"
echo "Try: uv run ruff format src/ tests/"
echo "Try: uv run ruff check src/ tests/"
echo "Try: uv run mypy src/"
