#!/usr/bin/env zsh
#MISE description="Setup Rust workspace project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:rust"]

echo "Setting up Rust workspace project..."

# Copy Rust-specific static files (will override base files if same name)
TEMPLATE_DIR="${0:a:h}/rust"
if [[ -d "$TEMPLATE_DIR" ]]; then
    echo "Copying Rust template files..."
    cp -r "$TEMPLATE_DIR"/. "$PWD/"
fi

PROJECT_NAME=$(basename "$PWD")
# Convert to valid Rust crate name (replace hyphens with underscores for module names)
CRATE_NAME="${PROJECT_NAME//-/_}"

# Get Rust version from mise
RUST_VERSION=$(mise exec -- rustc --version | awk '{print $2}')

echo "Creating workspace structure..."

# Create workspace directories
mkdir -p lib/src bin/src examples tests benches

# Create root Cargo.toml (workspace)
cat > "Cargo.toml" << EOF
[workspace]
members = ["lib", "bin"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2021"
authors = ["Your Name <your.email@example.com>"]
license = "MIT OR Apache-2.0"

[workspace.dependencies]
# Shared dependencies across workspace
anyhow = "1.0"
thiserror = "1.0"
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1.0", features = ["full"] }

[profile.release]
strip = true
lto = true
codegen-units = 1
EOF

# Create library Cargo.toml
cat > "lib/Cargo.toml" << EOF
[package]
name = "$PROJECT_NAME-lib"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true

[dependencies]
thiserror.workspace = true

[dev-dependencies]
EOF

# Create library code
cat > "lib/src/lib.rs" << 'EOF'
//! # Project Library
//!
//! This library provides core functionality for the project.

use thiserror::Error;

/// Custom error type for the library
#[derive(Error, Debug)]
pub enum Error {
    /// Configuration error
    #[error("configuration error: {0}")]
    Config(String),

    /// Invalid input error
    #[error("invalid input: {0}")]
    InvalidInput(String),
}

/// Result type alias for the library
pub type Result<T> = std::result::Result<T, Error>;

/// Greets a person by name
///
/// # Examples
///
/// ```
/// use PROJECT_NAME_lib::greet;
///
/// let greeting = greet("World");
/// assert_eq!(greeting, "Hello, World!");
/// ```
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

/// Performs a calculation
///
/// # Errors
///
/// Returns an error if the input is zero
pub fn calculate(value: i32) -> Result<i32> {
    if value == 0 {
        return Err(Error::InvalidInput("value cannot be zero".to_string()));
    }
    Ok(value * 2)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        assert_eq!(greet("Rust"), "Hello, Rust!");
    }

    #[test]
    fn test_calculate_success() {
        assert_eq!(calculate(5).unwrap(), 10);
    }

    #[test]
    fn test_calculate_error() {
        assert!(calculate(0).is_err());
    }
}
EOF

# Replace PROJECT_NAME placeholder in lib.rs
sed -i.bak "s/PROJECT_NAME/$CRATE_NAME/g" lib/src/lib.rs && rm lib/src/lib.rs.bak

# Create binary Cargo.toml
cat > "bin/Cargo.toml" << EOF
[package]
name = "$PROJECT_NAME-bin"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true

[[bin]]
name = "$PROJECT_NAME"
path = "src/main.rs"

[dependencies]
$PROJECT_NAME-lib = { path = "../lib" }
anyhow.workspace = true

[dev-dependencies]
EOF

# Create binary code
cat > "bin/src/main.rs" << 'EOF'
//! Main binary application

use anyhow::Result;
use PROJECT_NAME_lib::{greet, calculate};

fn main() -> Result<()> {
    println!("{}", greet("World"));

    let result = calculate(42)?;
    println!("Calculation result: {}", result);

    println!("\nProject is ready to build upon!");

    Ok(())
}
EOF

# Replace PROJECT_NAME placeholder in main.rs
sed -i.bak "s/PROJECT_NAME/$CRATE_NAME/g" bin/src/main.rs && rm bin/src/main.rs.bak

# Create example
cat > "examples/basic.rs" << 'EOF'
//! Basic usage example

use PROJECT_NAME_lib::greet;

fn main() {
    println!("Example: {}", greet("Example"));
}
EOF

# Replace PROJECT_NAME placeholder in example
sed -i.bak "s/PROJECT_NAME/$CRATE_NAME/g" examples/basic.rs && rm examples/basic.rs.bak

# Create integration test
cat > "tests/integration.rs" << 'EOF'
//! Integration tests

use PROJECT_NAME_lib::{greet, calculate};

#[test]
fn test_greet_integration() {
    let result = greet("Integration Test");
    assert!(result.contains("Integration Test"));
}

#[test]
fn test_calculate_integration() {
    let result = calculate(10).unwrap();
    assert_eq!(result, 20);
}

#[test]
fn test_calculate_error_integration() {
    let result = calculate(0);
    assert!(result.is_err());
}
EOF

# Replace PROJECT_NAME placeholder in integration test
sed -i.bak "s/PROJECT_NAME/$CRATE_NAME/g" tests/integration.rs && rm tests/integration.rs.bak

# Create benchmark
cat > "benches/benchmark.rs" << 'EOF'
//! Benchmarks
//!
//! Run with: cargo bench

use PROJECT_NAME_lib::greet;

fn main() {
    // Simple benchmark placeholder
    let iterations = 1_000_000;
    let start = std::time::Instant::now();

    for i in 0..iterations {
        let _ = greet(&format!("User {}", i));
    }

    let duration = start.elapsed();
    println!("Completed {} iterations in {:?}", iterations, duration);
    println!("Average: {:?} per iteration", duration / iterations);
}
EOF

# Replace PROJECT_NAME placeholder in benchmark
sed -i.bak "s/PROJECT_NAME/$CRATE_NAME/g" benches/benchmark.rs && rm benches/benchmark.rs.bak

echo "Installing cargo tools..."

# Install cargo tools using cargo install
mise exec -- cargo install cargo-watch cargo-nextest cargo-edit 2>/dev/null || {
    echo "Some cargo tools may already be installed or failed to install."
    echo "You can manually install them later with:"
    echo "  cargo install cargo-watch cargo-nextest cargo-edit"
}

echo "Building project..."
mise exec -- cargo build

echo "Running tests..."
if command -v cargo-nextest &> /dev/null; then
    mise exec -- cargo nextest run
else
    mise exec -- cargo test
fi

echo ""
echo "Rust workspace project setup complete!"
echo "Project structure:"
echo "  lib/  - Library crate ($PROJECT_NAME-lib)"
echo "  bin/  - Binary crate ($PROJECT_NAME-bin)"
echo ""
echo "Try: cargo run                          # Run the binary"
echo "Try: cargo test                         # Run all tests"
echo "Try: cargo nextest run                  # Run tests with nextest"
echo "Try: cargo run --example basic          # Run example"
echo "Try: cargo doc --open                   # Build and view docs"
echo "Try: cargo watch -x run                 # Auto-rebuild on changes"
echo "Try: cargo clippy                       # Run linter"
echo "Try: cargo fmt                          # Format code"
