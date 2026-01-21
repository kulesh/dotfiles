---
name: effective-python
description: Best practices for writing high-quality Python code. Use when writing, reviewing, or refactoring Python code. Covers strict typing, idiomatic patterns, performance, testing, and modern Python 3.14+ features. Apply these patterns to write Pythonic, maintainable, type-safe code.
---

# Effective Python

Write idiomatic, type-safe Python 3.14+ code following established best practices.

## Core Principles

1. **Strict typing by default** - All code uses type annotations
2. **Explicit over implicit** - Clear, readable code
3. **Composition over inheritance** - Prefer simple, composable designs
4. **Fail fast** - Raise exceptions early, use assertions

## Typing (Always Apply)

```python
from __future__ import annotations  # Always include for forward references
from typing import TypeVar, Generic, Protocol, Self, override
from collections.abc import Callable, Iterator, Sequence, Mapping
```

### Function Signatures
```python
def process_items(
    items: Sequence[str],
    *,  # Force keyword arguments after this
    transform: Callable[[str], str] | None = None,
    limit: int = 100,
) -> list[str]:
    """Process items with optional transformation.
    
    Args:
        items: Input strings to process.
        transform: Optional transformation function.
        limit: Maximum items to return.
        
    Returns:
        Processed list of strings.
        
    Raises:
        ValueError: If items is empty.
    """
    if not items:
        raise ValueError("items cannot be empty")
    
    result = list(items[:limit])
    if transform is not None:
        result = [transform(item) for item in result]
    return result
```

### Class Definitions
```python
from dataclasses import dataclass, field

@dataclass(frozen=True, slots=True)  # Prefer immutable dataclasses
class Config:
    """Application configuration."""
    host: str
    port: int = 8080
    tags: list[str] = field(default_factory=list)

class Service(Protocol):
    """Protocol for service implementations."""
    def process(self, data: bytes) -> bytes: ...
    
class BaseProcessor:
    """Base class with proper typing."""
    
    def __init__(self, config: Config) -> None:
        self._config = config
    
    @override  # Python 3.12+ - mark overridden methods
    def __repr__(self) -> str:
        return f"{type(self).__name__}(config={self._config})"
```

### Generics
```python
T = TypeVar("T")
K = TypeVar("K")
V = TypeVar("V")

def first_or_default(items: Sequence[T], default: T) -> T:
    """Return first item or default if empty."""
    return items[0] if items else default

class Cache(Generic[K, V]):
    """Generic cache with proper typing."""
    
    def __init__(self) -> None:
        self._data: dict[K, V] = {}
    
    def get(self, key: K, default: V | None = None) -> V | None:
        return self._data.get(key, default)
    
    def set(self, key: K, value: V) -> None:
        self._data[key] = value
```

## Pythonic Patterns

### Prefer f-strings
```python
# Good
name, count = "items", 42
message = f"Found {count} {name}"
log_entry = f"{name=}, {count=}"  # Debug format: "name='items', count=42"

# Avoid
message = "Found %d %s" % (count, name)  # C-style
message = "Found {} {}".format(count, name)  # str.format
```

### Unpacking Over Indexing
```python
# Good - unpacking
first, second, *rest = items
for index, value in enumerate(items, start=1):
    print(f"{index}: {value}")

# Good - parallel iteration
for name, score in zip(names, scores, strict=True):  # strict=True catches length mismatch
    print(f"{name}: {score}")

# Avoid
for i in range(len(items)):
    print(items[i])
```

### Walrus Operator for Assignment Expressions
```python
# Good - assign and test
if (match := pattern.search(text)) is not None:
    process(match.group(1))

if (n := len(items)) > 10:
    print(f"Processing {n} items")

# Good - in comprehensions  
valid = [y for x in data if (y := transform(x)) is not None]
```

### Comprehensions
```python
# Good - simple comprehensions
squares = [x**2 for x in range(10)]
even_squares = [x**2 for x in range(10) if x % 2 == 0]
lookup = {item.id: item for item in items}

# Avoid - complex comprehensions (use loops instead)
# Bad: more than 2 control expressions
result = [x for row in matrix for x in row if x > 0 if x < 100]

# Good - refactor complex logic to loops or helper functions
def process_matrix(matrix: list[list[int]]) -> list[int]:
    result: list[int] = []
    for row in matrix:
        for x in row:
            if 0 < x < 100:
                result.append(x)
    return result
```

### Generators for Large Data
```python
def read_large_file(path: str) -> Iterator[str]:
    """Yield lines without loading entire file."""
    with open(path) as f:
        for line in f:
            yield line.strip()

# Compose generators with yield from
def process_files(paths: Sequence[str]) -> Iterator[str]:
    for path in paths:
        yield from read_large_file(path)

# Generator expressions for memory efficiency
total = sum(len(line) for line in read_large_file("data.txt"))
```

## Functions

### Keyword-Only and Positional-Only Arguments
```python
def safe_divide(
    numerator: float,
    denominator: float,
    /,  # Positional-only before this
    *,  # Keyword-only after this
    round_digits: int | None = None,
) -> float:
    """Divide with optional rounding.
    
    Positional-only: numerator, denominator (can't use as keywords)
    Keyword-only: round_digits (must use as keyword)
    """
    result = numerator / denominator
    if round_digits is not None:
        result = round(result, round_digits)
    return result

# Usage
safe_divide(10, 3, round_digits=2)  # Good
safe_divide(numerator=10, denominator=3)  # Error - positional-only
safe_divide(10, 3, 2)  # Error - round_digits is keyword-only
```

### Raise Exceptions, Never Return None for Errors
```python
# Good
def find_user(user_id: int) -> User:
    """Find user by ID.
    
    Raises:
        KeyError: If user not found.
    """
    if user_id not in users:
        raise KeyError(f"User {user_id} not found")
    return users[user_id]

# Avoid - None is ambiguous
def find_user_bad(user_id: int) -> User | None:
    return users.get(user_id)  # Caller might forget to check None
```

### Dynamic Default Arguments
```python
# Good - use None sentinel
def append_item(
    item: str,
    target: list[str] | None = None,
) -> list[str]:
    if target is None:
        target = []  # Fresh list each call
    target.append(item)
    return target

# Avoid - mutable default (shared between calls!)
def append_item_bad(item: str, target: list[str] = []) -> list[str]:
    target.append(item)  # Bug: same list reused
    return target
```

### Decorators with functools.wraps
```python
from functools import wraps
from typing import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

def retry(max_attempts: int = 3) -> Callable[[Callable[P, R]], Callable[P, R]]:
    """Retry decorator with proper typing."""
    def decorator(func: Callable[P, R]) -> Callable[P, R]:
        @wraps(func)  # Preserves function metadata
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception:
                    if attempt == max_attempts - 1:
                        raise
            raise RuntimeError("Unreachable")
        return wrapper
    return decorator
```

## Classes

### Prefer Composition Over Deep Nesting
```python
# Good - compose with dataclasses
@dataclass(frozen=True, slots=True)
class Grade:
    score: float
    weight: float

@dataclass
class Student:
    name: str
    grades: dict[str, list[Grade]] = field(default_factory=dict)
    
    def add_grade(self, subject: str, grade: Grade) -> None:
        self.grades.setdefault(subject, []).append(grade)
    
    def average(self) -> float:
        total_score = sum(g.score * g.weight for gs in self.grades.values() for g in gs)
        total_weight = sum(g.weight for gs in self.grades.values() for g in gs)
        return total_score / total_weight if total_weight else 0.0

# Avoid - deeply nested dicts
grades: dict[str, dict[str, list[tuple[float, float]]]] = {}  # Unreadable
```

### Use Protocol for Structural Typing
```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...

def cleanup(resource: Closeable) -> None:
    """Works with any object having close() method."""
    resource.close()
```

### classmethod for Alternative Constructors
```python
@dataclass
class Connection:
    host: str
    port: int
    
    @classmethod
    def from_url(cls, url: str) -> Self:
        """Create from URL string."""
        # Parse url...
        return cls(host=parsed_host, port=parsed_port)
    
    @classmethod
    def local(cls) -> Self:
        """Create localhost connection."""
        return cls(host="localhost", port=8080)
```

### super() for Parent Initialization
```python
class Parent:
    def __init__(self, value: int) -> None:
        self.value = value

class Child(Parent):
    def __init__(self, value: int, extra: str) -> None:
        super().__init__(value)  # Always use super()
        self.extra = extra
```

## Dictionaries

### Handle Missing Keys Properly
```python
from collections import defaultdict

# Option 1: get() with default
count = counts.get(key, 0)

# Option 2: setdefault for mutable values
items_by_key.setdefault(key, []).append(item)

# Option 3: defaultdict for consistent pattern
counts: defaultdict[str, int] = defaultdict(int)
counts[key] += 1

# Option 4: __missing__ for complex logic
class CountingDict(dict[str, int]):
    def __missing__(self, key: str) -> int:
        self[key] = 0
        return 0
```

## Error Handling

### try/except/else/finally Pattern
```python
def read_config(path: str) -> dict[str, str]:
    """Read config with proper exception handling."""
    handle = None
    try:
        handle = open(path)
        data = handle.read()
    except FileNotFoundError:
        raise ConfigError(f"Config not found: {path}") from None
    except OSError as e:
        raise ConfigError(f"Failed to read config: {e}") from e
    else:
        # Runs only if no exception
        return parse_config(data)
    finally:
        # Always runs
        if handle is not None:
            handle.close()
```

### Context Managers
```python
from contextlib import contextmanager

@contextmanager
def temporary_directory() -> Iterator[str]:
    """Create and clean up temporary directory."""
    path = create_temp_dir()
    try:
        yield path
    finally:
        remove_dir(path)

# Usage
with temporary_directory() as tmpdir:
    process_files(tmpdir)
```

## Testing

### TestCase Structure
```python
import unittest
from unittest.mock import Mock, patch

class TestProcessor(unittest.TestCase):
    def setUp(self) -> None:
        """Set up test fixtures."""
        self.processor = Processor()
    
    def tearDown(self) -> None:
        """Clean up after tests."""
        self.processor.close()
    
    def test_process_valid_input(self) -> None:
        """Test processing with valid input."""
        result = self.processor.process("valid")
        self.assertEqual(result, "expected")
    
    def test_process_invalid_raises(self) -> None:
        """Test that invalid input raises ValueError."""
        with self.assertRaises(ValueError):
            self.processor.process("")

    @patch("module.external_service")
    def test_with_mock(self, mock_service: Mock) -> None:
        """Test with mocked dependency."""
        mock_service.return_value = "mocked"
        result = self.processor.call_service()
        mock_service.assert_called_once()
```

## Performance

### Profile Before Optimizing
```python
import cProfile
import pstats

def profile_code() -> None:
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Code to profile
    run_expensive_operation()
    
    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats("cumulative")
    stats.print_stats(10)  # Top 10
```

### Use Appropriate Data Structures
```python
from collections import deque
from heapq import heappush, heappop
from bisect import bisect_left

# deque for O(1) append/pop from both ends
queue: deque[str] = deque(maxlen=1000)
queue.append("item")
item = queue.popleft()

# heapq for priority queue
heap: list[tuple[int, str]] = []
heappush(heap, (priority, item))
_, item = heappop(heap)

# bisect for sorted sequence operations
sorted_list = [1, 3, 5, 7, 9]
index = bisect_left(sorted_list, 4)  # Find insertion point
```

## Concurrency

### Threads for I/O, Processes for CPU
```python
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor

# I/O-bound: use threads
def fetch_urls(urls: list[str]) -> list[str]:
    with ThreadPoolExecutor(max_workers=10) as executor:
        return list(executor.map(fetch_url, urls))

# CPU-bound: use processes
def compute_parallel(items: list[int]) -> list[int]:
    with ProcessPoolExecutor() as executor:
        return list(executor.map(heavy_computation, items))
```

### async/await for Concurrent I/O
```python
import asyncio
from collections.abc import Coroutine

async def fetch_all(urls: list[str]) -> list[str]:
    """Fetch URLs concurrently."""
    async with aiohttp.ClientSession() as session:
        tasks: list[Coroutine[None, None, str]] = [
            fetch_one(session, url) for url in urls
        ]
        return await asyncio.gather(*tasks)
```

## Additional References

For detailed patterns on specific topics, see:
- `references/typing-patterns.md` - Advanced typing patterns and generics
- `references/class-patterns.md` - Class design patterns and protocols