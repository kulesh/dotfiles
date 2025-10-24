---
description: Prepare the working tree for a commit by reviewing code, checking style, and updating the documentation.
allowed-tools: Bash(*)
---

## Context

- PROJECTS directory: !`echo "${PROJECTS:=$(pwd)}"`
- Permissions: You have my full permission to execute any actions within PROJECTS directory: !`echo "${PROJECTS:=$(pwd)}"` This directory is entirely under your control.
- Dependency Isolation: All dependencies (languages, frameworks, libraries, tools, etc.) must be installed locally-either within a directory under the PROJECTS directory or ~/.local/ **DO NOT** install or rely on a system-level dependency.

## Your Goal

Ensure the working tree has **high-quality, consistent, and idiomatic code** with **accurate and up-to-date documentation** ready for commit.

## Guardrails

- **Do not introduce new functionality or modify program behavior.** All edits must preserve existing logic and semantics.
- **Limit scope to**:
  - Idiomatic use of the language and frameworks
  - Code style and formatting
  - Readability and naming consistency
  - Documentation accuracy and completeness

## Your Tasks

1. **Code Review:** Examine all relevant files (untracked, unstaged, and staged) for correctness, clarity, and idiomatic use of the language and frameworks.
2. **Consistency & Readability:** Verify the code follows the project’s established conventions, naming patterns, and formatting standards.
3. **Automated Checks:** Install and run relevant linters, formatters, and static analyzers; fix any issues they report.
4. **Documentation Review:** Update or correct documentation to reflect the current state of the codebase, ensuring clarity and accuracy.
5. **Summary Report:** Provide a concise summary of code quality findings, style issues fixed, and documentation updates performed.

## Success Criteria

- Code is idiomatic.
- Code style is consistent, and passes all lint/style checks.
- Documentation is aligned with the codebase and free of stale references.
- No behavioral changes were made unless explicitly approved.
