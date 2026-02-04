## Project Overview
This is a Rust workspace project managed with:

- **mise-en-place** for Rust toolchain version management
- **cargo** for build system and package management
- **Workspace structure** with separate library and binary crates
- **cargo-nextest** for fast, modern test runner
- **cargo-watch** for auto-rebuild during development
- **clippy** for linting and **rustfmt** for formatting

## Key Commands

### Development

```bash
# Build the entire workspace
cargo build

# Build in release mode (optimized)
cargo build --release

# Build specific package
cargo build -p <project-name>-lib
cargo build -p <project-name>-bin

# Auto-rebuild on changes
cargo watch -x build

# Auto-rebuild and run
cargo watch -x run
```

### Running

```bash
# Run the binary
cargo run

# Run with arguments
cargo run -- --arg value

# Run release build
cargo run --release

# Run specific binary
cargo run -p <project-name>-bin
```

### Testing

```bash
# Run all tests (using nextest)
cargo nextest run

# Run all tests (standard)
cargo test

# Run tests with output
cargo nextest run --no-capture

# Run specific test
cargo nextest run <test_name>

# Run tests in specific package
cargo nextest run -p <project-name>-lib

# Run with coverage (requires cargo-llvm-cov)
cargo llvm-cov nextest

# Run doctests
cargo test --doc

# Run benchmarks
cargo bench
```

### Code Quality

```bash
# Format code
cargo fmt

# Check formatting without changing files
cargo fmt -- --check

# Lint with clippy
cargo clippy

# Clippy with all lints
cargo clippy -- -W clippy::all

# Fix clippy warnings automatically
cargo clippy --fix

# Check code without building
cargo check

# Check all targets (including tests, examples, benches)
cargo check --all-targets
```

### Dependencies

```bash
# Add a dependency (requires cargo-edit)
cargo add <crate_name>

# Add a dev dependency
cargo add --dev <crate_name>

# Add dependency to specific package
cargo add -p <project-name>-lib <crate_name>

# Update all dependencies
cargo update

# Show dependency tree
cargo tree

# Check for outdated dependencies (requires cargo-outdated)
cargo outdated
```

### Documentation

```bash
# Build and open documentation
cargo doc --open

# Build docs for all dependencies
cargo doc --open --no-deps

# Build docs for workspace
cargo doc --workspace --open
```

### Build & Clean

```bash
# Clean build artifacts
cargo clean

# Show build time breakdown (requires cargo-build-timings)
cargo build --timings
```

## Project Structure

```
<project-name>/
├── Cargo.toml              # Workspace configuration
├── lib/
│   ├── Cargo.toml          # Library package manifest
│   └── src/
│       └── lib.rs          # Library root module
├── bin/
│   ├── Cargo.toml          # Binary package manifest
│   └── src/
│       └── main.rs         # Binary entry point
├── examples/
│   └── basic.rs            # Example usage
├── tests/
│   └── integration.rs      # Integration tests
├── benches/
│   └── benchmark.rs        # Performance benchmarks
├── .mise.toml              # mise configuration
├── .gitignore              # Git ignore patterns
└── README.md               # Project documentation
```

## Development Guidelines

### Rust Idioms

- Use `Result<T, E>` and `Option<T>` for error handling and optional values
- Prefer iterators over manual loops
- Use `match` for exhaustive pattern matching
- Leverage the type system for compile-time guarantees
- Follow the Rust API Guidelines: https://rust-lang.github.io/api-guidelines/

### Error Handling

- Use `?` operator for error propagation
- Create custom error types using `thiserror` for libraries
- Use `anyhow` for application-level error handling (binary)
- Avoid `unwrap()` and `expect()` in library code
- Provide meaningful error messages

### Testing

- Write unit tests in the same file as the code using `#[cfg(test)]`
- Use integration tests in `tests/` for public API testing
- Use doctests for examples in documentation
- Test error cases, not just happy paths
- Use `assert_eq!`, `assert_ne!`, and custom assertions

### Code Organization

- Keep modules small and focused
- Use `pub(crate)` for internal APIs
- Export public API through `lib.rs` with clear module structure
- Group related functionality in modules
- Use trait objects and generics appropriately

### Performance

- Use `cargo bench` for performance-critical code
- Profile before optimizing
- Avoid premature optimization
- Use `#[inline]` judiciously
- Consider using `&str` over `String` where possible
- Use `Cow<str>` when you might need owned or borrowed strings

### Async Code

```bash
# Add async runtime if needed
cargo add tokio --features full
cargo add async-std
```

- Use async only when needed (I/O-bound operations)
- Choose appropriate runtime (tokio, async-std)
- Be mindful of `.await` points
- Use `spawn` for concurrent tasks
- Handle cancellation properly

## Common Patterns

### Error Handling with thiserror

```rust
// In lib/src/lib.rs
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Configuration error: {0}")]
    Config(String),

    #[error("IO error")]
    Io(#[from] std::io::Error),

    #[error("Invalid input: {0}")]
    InvalidInput(String),
}

pub type Result<T> = std::result::Result<T, AppError>;
```

### Using anyhow in Binary

```rust
// In bin/src/main.rs
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let config = load_config()
        .context("Failed to load configuration")?;

    run_app(config)?;
    Ok(())
}
```

### Builder Pattern

```rust
#[derive(Debug, Default)]
pub struct Config {
    pub host: String,
    pub port: u16,
}

impl Config {
    pub fn builder() -> ConfigBuilder {
        ConfigBuilder::default()
    }
}

#[derive(Default)]
pub struct ConfigBuilder {
    host: Option<String>,
    port: Option<u16>,
}

impl ConfigBuilder {
    pub fn host(mut self, host: impl Into<String>) -> Self {
        self.host = Some(host.into());
        self
    }

    pub fn port(mut self, port: u16) -> Self {
        self.port = Some(port);
        self
    }

    pub fn build(self) -> Config {
        Config {
            host: self.host.unwrap_or_else(|| "127.0.0.1".to_string()),
            port: self.port.unwrap_or(8080),
        }
    }
}
```

### Testing Patterns

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_functionality() {
        let result = some_function(42);
        assert_eq!(result, expected_value);
    }

    #[test]
    fn test_error_case() {
        let result = fallible_function("invalid");
        assert!(result.is_err());
    }

    #[test]
    #[should_panic(expected = "specific error message")]
    fn test_panic_case() {
        panic_function();
    }
}
```

### CLI Applications

```bash
# Add clap for CLI argument parsing
cargo add clap --features derive
```

```rust
use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    verbose: bool,

    #[arg(short, long, default_value = "config.toml")]
    config: String,
}

fn main() {
    let args = Args::parse();
    // Use args.verbose, args.config, etc.
}
```

## Common Dependencies

### Essential

```bash
cargo add anyhow          # Error handling (binary)
cargo add thiserror       # Error types (library)
cargo add serde --features derive  # Serialization
cargo add tokio --features full    # Async runtime
```

### CLI & Config

```bash
cargo add clap --features derive   # CLI parsing
cargo add config                   # Configuration
cargo add env_logger              # Logging
cargo add log                     # Logging facade
```

### Testing & Dev

```bash
cargo add --dev mockall           # Mocking
cargo add --dev proptest          # Property testing
cargo add --dev criterion         # Benchmarking
```

## Notes for Claude Code

- This is a workspace with separate lib and bin crates
- The binary (`bin/`) depends on the library (`lib/`)
- Always run `cargo fmt` before committing code
- Use `cargo clippy` to catch common mistakes
- Run `cargo nextest run` for faster test execution
- Check `Cargo.toml` in each package for dependencies
- Use `Result` types instead of panicking in library code
- Follow existing code style and patterns
- Update benchmarks when optimizing performance
- Keep the library crate (`lib/`) free of application logic
- Documentation comments use `///` and support markdown
- Use `cargo doc --open` to preview documentation
