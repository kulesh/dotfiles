#!/usr/bin/env zsh
#MISE description="Setup TypeScript monorepo with Ink CLI"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:typescript"]

echo "Setting up TypeScript workspace project..."

# Copy TypeScript-specific static files (includes CLAUDE.md)
TEMPLATE_DIR="${0:a:h}/typescript"
if [[ -d "$TEMPLATE_DIR" ]]; then
    echo "Copying TypeScript template files..."
    cp -r "$TEMPLATE_DIR"/. "$PWD/"
fi

PROJECT_NAME=$(basename "$PWD")
# For scoped packages
PACKAGE_SCOPE="@${PROJECT_NAME}"

echo "Creating workspace structure..."

# Create directory structure
mkdir -p packages/core/{src,tests}
mkdir -p packages/cli/{src/components,tests}

# Create root package.json
cat > "package.json" << EOF
{
  "name": "$PROJECT_NAME",
  "private": true,
  "type": "module",
  "workspaces": ["packages/*"],
  "scripts": {
    "build": "bun run --filter '*' build",
    "dev": "bun run --filter cli dev",
    "test": "vitest",
    "test:run": "vitest run",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write .",
    "typecheck": "bun run --filter '*' typecheck",
    "clean": "rm -rf packages/*/dist"
  },
  "devDependencies": {
    "@biomejs/biome": "latest",
    "@types/bun": "latest",
    "typescript": "latest",
    "vitest": "latest"
  }
}
EOF

# Create root tsconfig.json
cat > "tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "jsxImportSource": "react"
  },
  "exclude": ["node_modules", "dist"]
}
EOF

# Create biome.json
cat > "biome.json" << 'EOF'
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "tab",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "style": {
        "noNonNullAssertion": "warn",
        "useConst": "error"
      },
      "correctness": {
        "noUnusedVariables": "error",
        "noUnusedImports": "error"
      },
      "suspicious": {
        "noExplicitAny": "warn"
      }
    }
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingCommas": "all"
    }
  },
  "files": {
    "ignore": ["node_modules", "dist", "*.config.ts", "*.config.js"]
  }
}
EOF

# Create vitest.config.ts
cat > "vitest.config.ts" << 'EOF'
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['packages/**/tests/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      include: ['packages/*/src/**/*.{ts,tsx}'],
    },
  },
});
EOF

# Create packages/core/package.json
cat > "packages/core/package.json" << EOF
{
  "name": "${PACKAGE_SCOPE}/core",
  "version": "0.1.0",
  "type": "module",
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": {
        "types": "./dist/index.d.ts",
        "default": "./dist/index.js"
      },
      "require": {
        "types": "./dist/index.d.cts",
        "default": "./dist/index.cjs"
      }
    }
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsup",
    "dev": "tsup --watch",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "tsup": "latest"
  }
}
EOF

# Create packages/core/tsconfig.json
cat > "packages/core/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
EOF

# Create packages/core/tsup.config.ts
cat > "packages/core/tsup.config.ts" << 'EOF'
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm', 'cjs'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
});
EOF

# Create packages/core/src/index.ts
cat > "packages/core/src/index.ts" << 'EOF'
export { greet, calculate } from './lib';
export type { GreetOptions, CalculateResult } from './lib';
EOF

# Create packages/core/src/lib.ts
cat > "packages/core/src/lib.ts" << 'EOF'
/**
 * Options for the greet function
 */
export interface GreetOptions {
  name: string;
  enthusiasm?: boolean;
}

/**
 * Result of a calculation
 */
export interface CalculateResult {
  value: number;
  operation: string;
}

/**
 * Greets a person by name
 *
 * @example
 * ```ts
 * const message = greet({ name: 'World' });
 * // => "Hello, World!"
 * ```
 */
export function greet(options: GreetOptions): string {
  const { name, enthusiasm = false } = options;
  const punctuation = enthusiasm ? '!!' : '!';
  return `Hello, ${name}${punctuation}`;
}

/**
 * Performs a calculation and returns the result
 *
 * @throws {Error} When value is zero
 */
export function calculate(value: number): CalculateResult {
  if (value === 0) {
    throw new Error('Value cannot be zero');
  }
  return {
    value: value * 2,
    operation: 'double',
  };
}
EOF

# Create packages/core/tests/lib.test.ts
cat > "packages/core/tests/lib.test.ts" << 'EOF'
import { describe, expect, it } from 'vitest';
import { calculate, greet } from '../src';

describe('greet', () => {
  it('greets with default punctuation', () => {
    expect(greet({ name: 'World' })).toBe('Hello, World!');
  });

  it('greets with enthusiasm', () => {
    expect(greet({ name: 'World', enthusiasm: true })).toBe('Hello, World!!');
  });
});

describe('calculate', () => {
  it('doubles the input value', () => {
    const result = calculate(21);
    expect(result.value).toBe(42);
    expect(result.operation).toBe('double');
  });

  it('throws on zero input', () => {
    expect(() => calculate(0)).toThrow('Value cannot be zero');
  });
});
EOF

# Create packages/cli/package.json
cat > "packages/cli/package.json" << EOF
{
  "name": "${PACKAGE_SCOPE}/cli",
  "version": "0.1.0",
  "type": "module",
  "bin": {
    "$PROJECT_NAME": "./src/index.tsx"
  },
  "scripts": {
    "dev": "bun run src/index.tsx",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "${PACKAGE_SCOPE}/core": "workspace:*",
    "ink": "latest",
    "react": "latest"
  },
  "devDependencies": {
    "@types/react": "latest",
    "ink-testing-library": "latest"
  }
}
EOF

# Create packages/cli/tsconfig.json
cat > "packages/cli/tsconfig.json" << 'EOF'
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
EOF

# Create packages/cli/src/index.tsx
cat > "packages/cli/src/index.tsx" << 'EOF'
#!/usr/bin/env bun
import { render } from 'ink';
import { App } from './app.js';

render(<App />);
EOF

# Create packages/cli/src/app.tsx
cat > "packages/cli/src/app.tsx" << EOF
import { Box, Text } from 'ink';
import { greet } from '${PACKAGE_SCOPE}/core';
import { Counter } from './components/counter.js';

export function App() {
  const message = greet({ name: 'TypeScript', enthusiasm: true });

  return (
    <Box flexDirection="column" padding={1}>
      <Text color="green" bold>
        {message}
      </Text>
      <Box marginTop={1}>
        <Counter label="Count" />
      </Box>
      <Box marginTop={1}>
        <Text dimColor>Press Ctrl+C to exit</Text>
      </Box>
    </Box>
  );
}
EOF

# Create packages/cli/src/components/counter.tsx
cat > "packages/cli/src/components/counter.tsx" << 'EOF'
import { Text } from 'ink';
import { useEffect, useState } from 'react';

interface CounterProps {
  label?: string;
}

export function Counter({ label = 'Counter' }: CounterProps) {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCount((prev) => prev + 1);
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  return (
    <Text>
      {label}: <Text color="cyan">{count}</Text>
    </Text>
  );
}
EOF

# Create packages/cli/tests/app.test.tsx
cat > "packages/cli/tests/app.test.tsx" << 'EOF'
import { render } from 'ink-testing-library';
import { describe, expect, it } from 'vitest';
import { App } from '../src/app';

describe('App', () => {
  it('renders greeting message', () => {
    const { lastFrame } = render(<App />);
    expect(lastFrame()).toContain('Hello, TypeScript!!');
  });

  it('renders counter label', () => {
    const { lastFrame } = render(<App />);
    expect(lastFrame()).toContain('Count:');
  });
});
EOF

# Update CLAUDE.md with actual project name
sed -i.bak "s/<project-name>/$PROJECT_NAME/g" CLAUDE.md && rm -f CLAUDE.md.bak

# Extend .gitignore with TypeScript-specific patterns
cat >> .gitignore << 'EOF'

# TypeScript
dist/
*.tsbuildinfo

# Bun
bun.lockb

# Test coverage
coverage/

# Build artifacts
*.js.map
*.d.ts.map
EOF

echo "Installing dependencies..."
mise exec -- bun install

echo "Building core library..."
mise exec -- bun run --filter "${PACKAGE_SCOPE}/core" build

echo "Running type checks..."
mise exec -- bun run typecheck || true

echo "Running tests..."
mise exec -- bun run test:run || true

echo ""
echo "TypeScript workspace project setup complete!"
echo "Project structure:"
echo "  packages/core/  - Library (${PACKAGE_SCOPE}/core)"
echo "  packages/cli/   - Ink CLI (${PACKAGE_SCOPE}/cli)"
echo ""
echo "Available commands:"
echo "  bun run dev        # Run the CLI in development"
echo "  bun run build      # Build all packages"
echo "  bun run test       # Run tests in watch mode"
echo "  bun run test:run   # Run tests once"
echo "  bun run lint       # Check with Biome"
echo "  bun run lint:fix   # Fix linting issues"
echo "  bun run format     # Format code"
echo "  bun run typecheck  # Run TypeScript checks"
