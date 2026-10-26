# ADR-007: The Editor Uses Each Project's Own Tooling

**Status:** Accepted
**Date:** 2026-10-26

## Context

Neovim formatted Python with black and isort and type-checked with pyright, while the project templates used ruff and mypy. Mason installed every tool globally, so the editor, the project's own checks and coding agents could run different tools, or different versions of the same tool, and disagree. The LSP setup also used APIs removed in nvim 0.11 and mason-lspconfig v2, and `typescript@latest` became TypeScript 7, which ships no `tsserver`.

## Decision

The editor runs the project's tools, at the project's versions.

| Language | Format + lint | Types / LSP | Comes from |
|----------|---------------|-------------|------------|
| Python | ruff | basedpyright | project `.venv` (mise `_.python.venv`), else Mason |
| TypeScript 7+ | Biome (if `biome.json`), else Prettier | `tsc --lsp` | project `node_modules` |
| TypeScript <7 | same | ts_ls | Mason |
| Rust | rustfmt + clippy | rust-analyzer | Rust toolchain (rustup component) |
| Swift | swift-format | sourcekit-lsp | Xcode |
| Ruby | RuboCop | ruby-lsp | project bundle |

- **One rule for starting a server:** start it when its binary is on PATH, whoever installed it. Mason's bin directory goes at the end of PATH, so a project's copy always wins and Mason's is the fallback.
- **Templates and editor agree:** Python templates use basedpyright and ruff; TypeScript and Convex templates use Biome. Templates finish by running their own fixers (`ruff check --fix`, `ruff format`, `biome migrate`, `biome check --write`), so generated code passes the project's checks and the config matches the installed tool version.
- **Native LSP API:** `vim.lsp.config()` and `vim.lsp.enable()`; `lazy-lock.json` is committed so plugin versions are pinned.

## Rejected alternatives

- **Mason-only tooling**: simplest, but versions drift from each project's.
- **mypy in templates, pyright in the editor**: two type checkers report different errors on the same code.
- **ts_ls everywhere**: on TypeScript 7 it falls back to its own bundled TypeScript.
- **Astral's `ty`**: promising, but in beta when this was decided.

## Consequences

- Opening a project shows the same errors its checks and agents see
- A repo without its own tools still works, through the Mason fallbacks
- Projects whose `.mise.toml` predates `_.python.venv` use Mason's copies until the venv is activated
- Tools at `latest` keep moving (Biome 1→2, TypeScript 6→7 both broke templates); running the tool's own migration at generation time absorbs most of that
