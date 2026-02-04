## Project Overview
This is a FastAPI application managed with:

- **mise-en-place** for Python version and development tools
- **uv** for fast Python package management
- **FastAPI** modern async web framework
- **Pydantic** for data validation and settings management
- **pytest** for testing

## Key Commands

### Development Server

```bash
# Start development server with auto-reload
uv run uvicorn <module_name>.main:app --reload

# Start server with custom host/port
uv run uvicorn <module_name>.main:app --host 0.0.0.0 --port 8080 --reload

# Using the project entry point
uv run <project_name>
```

### API Documentation

```bash
# Start server, then visit:
# - Swagger UI: http://localhost:8000/docs
# - ReDoc: http://localhost:8000/redoc
# - OpenAPI JSON: http://localhost:8000/openapi.json
```

### Testing

```bash
# Run all tests with coverage
uv run pytest

# Run specific test file
uv run pytest tests/test_main.py

# Run with verbose output
uv run pytest -v

# Run with coverage report
uv run pytest --cov=src/<module_name> --cov-report=html
```

### Code Quality

```bash
# Format code with black
uv run black src/ tests/

# Lint with ruff
uv run ruff check src/ tests/

# Type check with mypy
uv run mypy src/

# Run all quality checks
uv run black src/ tests/ && uv run ruff check src/ tests/ && uv run mypy src/
```

### Dependencies

```bash
# Add a package
uv add <package_name>

# Add a dev dependency
uv add --dev <package_name>

# Sync dependencies (after manual pyproject.toml edits)
uv sync

# Update all dependencies
uv lock --upgrade
uv sync
```

## Project Structure

```
src/<module_name>/
├── __init__.py           # Package initialization
├── main.py               # FastAPI app and entry point
├── api/
│   ├── __init__.py
│   └── routes.py         # API route handlers
├── core/
│   ├── __init__.py
│   └── config.py         # Application configuration
├── models/
│   └── __init__.py       # Database models (if using ORM)
└── schemas/
    ├── __init__.py
    └── items.py          # Pydantic schemas

tests/
├── test_main.py          # Application tests
└── test_api.py           # API endpoint tests

pyproject.toml            # Project metadata and dependencies
.env.example              # Environment variable template
```

## Development Guidelines

### FastAPI Patterns

- Use async/await for I/O operations (database, external APIs)
- Define Pydantic schemas for request/response validation
- Use dependency injection for shared resources
- Leverage automatic API documentation

### API Design

- Follow RESTful conventions where applicable
- Use appropriate HTTP status codes
- Version your API (e.g., `/api/v1/`)
- Return consistent error responses

### Configuration

- Use Pydantic Settings for configuration management
- Store secrets in environment variables (never in code)
- Use `.env` file for local development (add to .gitignore)
- Provide `.env.example` with all required variables

### Testing

- Test all endpoints with TestClient
- Test both success and error cases
- Mock external dependencies
- Aim for high test coverage on business logic

### Code Quality

- Follow PEP 8 style guide (enforced by black)
- Use type hints for all functions
- Keep route handlers thin - move logic to services
- Document complex business logic

### Performance

- Use async database drivers (asyncpg, motor, etc.)
- Implement caching for expensive operations
- Use background tasks for non-blocking operations
- Consider pagination for list endpoints

## Common Patterns

### Adding a new endpoint

```python
# In api/routes.py
from fastapi import APIRouter, HTTPException
from ..schemas.items import ItemCreate, ItemResponse

router = APIRouter()

@router.post("/items", response_model=ItemResponse, status_code=201)
async def create_item(item: ItemCreate):
    # Business logic here
    return ItemResponse(id=1, **item.dict())
```

### Using dependencies

```python
from fastapi import Depends
from ..core.config import settings

async def get_current_user(token: str = Depends(oauth2_scheme)):
    # Authentication logic
    return user

@router.get("/me")
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user
```

### Error handling

```python
from fastapi import HTTPException

@router.get("/items/{item_id}")
async def get_item(item_id: int):
    item = await get_item_from_db(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
```

### Background tasks

```python
from fastapi import BackgroundTasks

def send_email(email: str, message: str):
    # Send email logic
    pass

@router.post("/send-notification")
async def send_notification(email: str, background_tasks: BackgroundTasks):
    background_tasks.add_task(send_email, email, "Hello!")
    return {"message": "Notification sent in background"}
```

## Database Integration

### Using SQLAlchemy (async)

```bash
uv add sqlalchemy[asyncio] asyncpg
```

### Using SQLModel (recommended for FastAPI)

```bash
uv add sqlmodel
```

### Using MongoDB (async)

```bash
uv add motor
```

## Notes for Claude Code

- Check `src/<module_name>/core/config.py` for configuration options
- Review `pyproject.toml` for Python version and dependencies
- Use FastAPI's automatic docs at `/docs` to understand API structure
- Respect the async/await pattern throughout the codebase
- When adding endpoints, update tests accordingly
- Use Pydantic models for data validation - don't bypass them
- Check `.env.example` for required environment variables
- Follow the existing project structure for consistency
