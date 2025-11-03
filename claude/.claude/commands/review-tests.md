---
description: Perform a thorough review and improvement of the test suite
allowed-tools: Bash(*:*), Read, Write, Edit, Glob, Grep, Task, TodoWrite
---

## Context

- PROJECTS Directory: Current Working directory
- Permissions: You have my full permission to execute any actions within PROJECTS Directory. This directory is entirely under your control.
- Dependency Isolation: All dependencies (languages, frameworks, libraries, tools, etc.) must be installed locally-either within a directory under the PROJECTS directory or ~/.local/ **DO NOT** install or rely on a system-level dependency.

## Your Goal

Ensure the test suite is **complete** (frontend and backend, if they both exist), **correct**, and **useful**—providing reliable coverage of all essential functionality and meaningful validation of core logic.

## Guardrails

1. **DO NOT modify application code while reviewing or improving tests.**
2. Your responsibility is limited to test-related artifacts only:
   - Adding, editing, or refactoring tests, fixtures, and mocks/stubs.
   - Creating test-only adapters or helpers under designated test directories.
   - Adjusting CI/build configuration strictly to enable test execution.

## Your Tasks

1. **Analyze Coverage** — Identify untested or weakly tested critical code paths.
2. **Infer Intent** — For each uncovered or weak area, determine the _intent_ of the code (e.g., purpose of a function or module).
3. **Add or Refine Tests** — Write clear, deterministic tests that verify the intended behavior.
4. **Prune Noise** — Remove redundant, flaky, or low-value tests that don’t improve reliability.
5. **Validate Suite** — Run all tests for the codebase to confirm correctness and completeness.
6. **Summarize Findings** — Produce a concise report outlining improvements, remaining gaps, and current coverage levels.

## Success Criteria

- All critical logic paths have deterministic test coverage.
- Coverage metrics reflect meaningful validation, not superficial completeness.
- The test suite runs cleanly in isolation with no global dependencies.
