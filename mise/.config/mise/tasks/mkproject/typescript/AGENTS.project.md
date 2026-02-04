## Project Overview
This is a TypeScript monorepo managed with:

- **mise-en-place** for Bun runtime version management
- **Bun** as the JavaScript/TypeScript runtime and package manager
- **Bun workspaces** for monorepo package management
- **tsup** for building the core library (ESM + CJS)
- **Ink** for React-based terminal UI in the CLI
- **Biome** for linting and formatting
- **Vitest** for testing

## Key Commands

### Development

```bash
# Run the CLI in development
bun run dev

# Build all packages
bun run build

# Build specific package
bun run --filter @<project-name>/core build

# Watch mode for library development
cd packages/core && bun run dev
```

### Testing

```bash
# Run tests in watch mode
bun run test

# Run tests once
bun run test:run

# Run tests with coverage
bun run test -- --coverage

# Run specific test file
bun run test packages/core/tests/lib.test.ts
```

### Code Quality

```bash
# Check linting and formatting
bun run lint

# Fix linting and formatting issues
bun run lint:fix

# Format code only
bun run format

# Type check all packages
bun run typecheck
```

### Dependencies

```bash
# Add dependency to root
bun add <package>

# Add dependency to specific package
bun add <package> --filter @<project-name>/core

# Add dev dependency
bun add -d <package>

# Update all dependencies
bun update
```

## Project Structure

```
<project-name>/
├── package.json           # Root workspace config
├── biome.json             # Linter/formatter config
├── tsconfig.json          # Base TypeScript config
├── vitest.config.ts       # Test configuration
├── packages/
│   ├── core/              # Library package
│   │   ├── src/           # Source code
│   │   ├── tests/         # Unit tests
│   │   ├── tsup.config.ts # Build configuration
│   │   └── dist/          # Built output (ESM + CJS)
│   └── cli/               # Ink CLI package
│       ├── src/           # React components
│       │   └── components/
│       └── tests/         # Component tests
```

## Development Guidelines

### TypeScript Best Practices

- Use strict mode (enabled by default)
- Prefer `interface` over `type` for object shapes
- Use `unknown` instead of `any` where possible
- Export types alongside runtime code
- Use barrel exports in `index.ts` files

### Library Development (packages/core)

- Keep the library focused and minimal
- Export all public types from `index.ts`
- Write comprehensive JSDoc comments
- Ensure both ESM and CJS outputs work correctly
- Test with `@arethetypeswrong/cli` before publishing

### Ink CLI Development (packages/cli)

- Use functional components with hooks
- Keep components small and focused
- Use `<Box>` for layout with flexbox props
- Use `<Text>` for all text output (supports colors)
- Handle Ctrl+C gracefully with cleanup

### Testing

- Write unit tests for all exported functions
- Test both success and error cases
- Use `ink-testing-library` for component tests
- Aim for high coverage on business logic

### Code Style (Biome)

- Use tabs for indentation
- Single quotes for strings
- Trailing commas everywhere
- 100 character line width
- Imports auto-organized

## Common Patterns

### Adding a new library function

```typescript
// In packages/core/src/lib.ts
export interface MyFunctionOptions {
  param: string;
}

export function myFunction(options: MyFunctionOptions): string {
  // Implementation
}

// In packages/core/src/index.ts
export { myFunction } from './lib';
export type { MyFunctionOptions } from './lib';
```

### Adding an Ink component

```tsx
// In packages/cli/src/components/my-component.tsx
import { Box, Text } from 'ink';

interface MyComponentProps {
  title: string;
}

export function MyComponent({ title }: MyComponentProps) {
  return (
    <Box>
      <Text bold>{title}</Text>
    </Box>
  );
}
```

### Using core library in CLI

```tsx
import { greet } from '@<project-name>/core';

export function App() {
  const message = greet({ name: 'User' });
  return <Text>{message}</Text>;
}
```

### Interactive input with Ink

```tsx
import { useInput, useApp } from 'ink';

export function InteractiveComponent() {
  const { exit } = useApp();

  useInput((input, key) => {
    if (input === 'q' || key.escape) {
      exit();
    }
  });

  return <Text>Press 'q' to quit</Text>;
}
```

## Notes for Claude Code

- This is a Bun workspace - use `bun` instead of `npm` or `yarn`
- The CLI (`packages/cli`) depends on the library (`packages/core`)
- Always build core before running CLI if you change library code
- Use `bun run --filter <package>` to run scripts in specific packages
- Biome handles both linting AND formatting (no separate prettier)
- JSX files use `.tsx` extension even with Bun
- Type exports must be explicit (`export type { ... }`)
- Check `biome.json` for linting rules before making style changes
