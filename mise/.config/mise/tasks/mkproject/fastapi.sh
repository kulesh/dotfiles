#!/usr/bin/env zsh
#MISE description="Setup FastAPI project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:python"]

echo "Setting up FastAPI project..."

PROJECT_NAME=$(basename "$PWD")
# Convert to valid Python module name (replace hyphens with underscores)
MODULE_NAME="${PROJECT_NAME//-/_}"

# Get Python version from mise
PYTHON_VERSION=$(mise exec -- python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

# Create FastAPI project structure
mkdir -p src/$MODULE_NAME/{api,core,models,schemas} tests

# Create pyproject.toml with FastAPI dependencies
cat > "pyproject.toml" << EOF
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$PROJECT_NAME"
version = "0.1.0"
description = "A FastAPI project"
requires-python = ">= $PYTHON_VERSION"
dependencies = [
    "fastapi",
    "uvicorn[standard]",
    "pydantic",
    "pydantic-settings"
]

[project.optional-dependencies]
dev = [
    "pytest",
    "pytest-asyncio",
    "httpx",
    "pytest-cov",
    "black",
    "ruff",
    "mypy"
]

[project.scripts]
$PROJECT_NAME = "$MODULE_NAME:main"

[tool.black]
line-length = 88

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
asyncio_mode = "auto"
EOF

# Create package __init__.py
cat > "src/$MODULE_NAME/__init__.py" << EOF
"""$PROJECT_NAME - A FastAPI project."""

from .main import app, main

__version__ = "0.1.0"
__all__ = ["app", "main"]
EOF

# Create main FastAPI application
cat > "src/$MODULE_NAME/main.py" << EOF
"""Main FastAPI application."""

from fastapi import FastAPI
from .api.routes import router
from .core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="A FastAPI project"
)

app.include_router(router, prefix="/api/v1")


@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": f"Welcome to {settings.PROJECT_NAME}!"}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


def main() -> None:
    """Entry point for running the application."""
    import uvicorn
    uvicorn.run(
        "$(echo $MODULE_NAME).main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )


if __name__ == "__main__":
    main()
EOF

# Create configuration
cat > "src/$MODULE_NAME/core/__init__.py" << EOF
"""Core configuration and utilities."""
EOF

cat > "src/$MODULE_NAME/core/config.py" << EOF
"""Application configuration."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""
    
    PROJECT_NAME: str = "$PROJECT_NAME"
    VERSION: str = "0.1.0"
    DEBUG: bool = True
    HOST: str = "127.0.0.1"
    PORT: int = 8000
    
    class Config:
        env_file = ".env"


settings = Settings()
EOF

# Create API routes
cat > "src/$MODULE_NAME/api/__init__.py" << EOF
"""API package."""
EOF

cat > "src/$MODULE_NAME/api/routes.py" << EOF
"""API routes."""

from fastapi import APIRouter
from ..schemas.items import Item, ItemCreate, ItemResponse

router = APIRouter()


@router.get("/items", response_model=list[ItemResponse])
async def get_items():
    """Get all items."""
    return [
        ItemResponse(id=1, name="Item 1", description="First item"),
        ItemResponse(id=2, name="Item 2", description="Second item")
    ]


@router.post("/items", response_model=ItemResponse)
async def create_item(item: ItemCreate):
    """Create a new item."""
    return ItemResponse(id=999, name=item.name, description=item.description)
EOF

# Create schemas
cat > "src/$MODULE_NAME/schemas/__init__.py" << EOF
"""Pydantic schemas."""
EOF

cat > "src/$MODULE_NAME/schemas/items.py" << EOF
"""Item schemas."""

from pydantic import BaseModel


class ItemBase(BaseModel):
    """Base item schema."""
    name: str
    description: str | None = None


class ItemCreate(ItemBase):
    """Schema for creating items."""
    pass


class Item(ItemBase):
    """Item schema with ID."""
    id: int


class ItemResponse(Item):
    """Item response schema."""
    
    class Config:
        from_attributes = True
EOF

# Create models directory
cat > "src/$MODULE_NAME/models/__init__.py" << EOF
"""Database models."""
EOF

# Create comprehensive tests
cat > "tests/test_main.py" << EOF
"""Tests for main application."""

import pytest
from fastapi.testclient import TestClient
from $MODULE_NAME import app

client = TestClient(app)


def test_root():
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "$PROJECT_NAME" in data["message"]


def test_health_check():
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
EOF

cat > "tests/test_api.py" << EOF
"""Tests for API routes."""

import pytest
from fastapi.testclient import TestClient
from $MODULE_NAME import app

client = TestClient(app)


def test_get_items():
    """Test getting items."""
    response = client.get("/api/v1/items")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2


def test_create_item():
    """Test creating an item."""
    item_data = {"name": "Test Item", "description": "A test item"}
    response = client.post("/api/v1/items", json=item_data)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test Item"
    assert data["description"] == "A test item"
    assert "id" in data
EOF

# Create environment file template
cat > ".env.example" << EOF
# FastAPI Configuration
PROJECT_NAME=$PROJECT_NAME
DEBUG=true
HOST=127.0.0.1
PORT=8000
EOF

# Install dependencies and setup
mise exec -- uv add fastapi "uvicorn[standard]" pydantic pydantic-settings
mise exec -- uv add --dev pytest pytest-asyncio httpx pytest-cov black ruff mypy
mise exec -- uv pip install -e .
mise exec -- uv sync

echo "FastAPI project setup complete!"
echo "Try: uv run $PROJECT_NAME              # Start the server"
echo "Try: uv run uvicorn $MODULE_NAME.main:app --reload"
echo "Try: uv run pytest                    # Run tests"
echo "Try: curl http://localhost:8000       # Test the API"
echo "Try: curl http://localhost:8000/api/v1/items"
