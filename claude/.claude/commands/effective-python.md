---
description: Write high-quality, idiomatic, and type-safe Python for backend services and CLI tooling.
allowed-tools: Bash(:), Read, Write, Edit, Glob, Grep, Task, TodoWrite
---

## Context

• PROJECTS Directory: Current working directory
• Permissions: Full permission to execute actions within the PROJECTS directory
• Dependency Isolation: All dependencies must be installed locally (under PROJECTS or ~/.local/). Do not rely on system-level dependencies.
• Language Baseline: Python ≥ 3.11
• Typing Mode: Strict (mypy / pyright equivalent)

## Your Goal

Produce Python code that is:
• Correct by construction (clear invariants, explicit error handling)
• Obvious and readable (optimize for the next human reader)
• Operationally safe (predictable I/O, concurrency, and failure modes)
• Type-safe (types are part of the API, not decoration)

Avoid cleverness unless it demonstrably reduces risk or complexity.

## Guardrails

• Do not introduce unnecessary abstraction or metaprogramming.
• Do not sacrifice readability for conciseness.
• Do not weaken type safety (avoid Any except at system boundaries).
• Do not rely on undefined behavior, implementation quirks, or side effects.
• Do not hide expensive work or I/O behind properties or magic methods.

## Your Tasks

1. Language and Style Discipline
   • Target Python 3 only; never emit Python 2 idioms.
   • Follow PEP 8 strictly; assume formatting is enforced by tools.
   • Prefer explicitness over implicit or clever constructs.
   • Use f-strings for string formatting; avoid % formatting.

2. Text, Bytes, and I/O Boundaries
   • Treat str as Unicode text and bytes as raw bytes.
   • Never mix text and bytes implicitly.
   • Perform encoding/decoding only at system boundaries (files, sockets, subprocesses).
   • Open files explicitly:
   • Binary data: rb, wb
   • Text data: specify encoding= when ambiguity exists

3. Functions and APIs
   • Raise exceptions for error conditions; do not return sentinel values like None.
   • Use keyword arguments for clarity; do not pass optional arguments positionally.
   • Use keyword-only arguments (\*) for flags and configuration.
   • Use positional-only arguments (/) to prevent coupling to parameter names when appropriate.
   • Never use mutable default arguments; use None and initialize internally.
   • Avoid returning more than three values; prefer small objects or dataclasses.

4. Iteration and Control Flow
   • Prefer unpacking over indexing when structure is known.
   • Use enumerate() instead of range(len(...)).
   • Use zip() for parallel iteration; itertools.zip_longest() when lengths may differ.
   • Avoid for/else and while/else constructs.
   • Break dense expressions into named steps or helper functions.

5. Data Structures and Collections
   • Prefer dict.get() for simple defaults.
   • Use collections.defaultdict for internal container state.
   • Use setdefault() sparingly and intentionally.
   • Implement **missing**() when default creation depends on the key or is expensive.
   • Do not rely on dictionary insertion order unless explicitly required and documented.

6. Comprehensions and Generators
   • Prefer comprehensions over map and filter.
   • Limit comprehensions to at most two control clauses (loops / conditionals).
   • Use generators for large data sets, streaming, or to avoid intermediate allocations.
   • If an iterable must be consumed multiple times, require a container or an iterator factory.
   • Use yield from for generator composition.
   • Avoid advanced generator control (send, throw) unless the flow is obvious and documented.

7. Classes and Data Modeling
   • Promote structure into classes once data becomes nested or behaviorful.
   • Prefer @dataclass for pure data containers.
   • Prefer functions for simple hooks; use callable objects when state is required.
   • Use super() correctly, especially with multiple inheritance.
   • Prefer mixins for composable behavior; avoid deep inheritance hierarchies.
   • Inherit from collections.abc when implementing container-like objects.

8. Attributes, Properties, and Metaprogramming
   • Start with plain attributes.
   • Introduce @property only for validation or derived values.
   • Properties must be fast and unsurprising.
   • Prefer **init_subclass**() over metaclasses for validation or registration.
   • Prefer class decorators over metaclasses when possible.

9. Concurrency and Parallelism
   • Use threads only for blocking I/O, not CPU-bound work.
   • Use concurrent.futures.ProcessPoolExecutor for CPU parallelism.
   • Never spawn unbounded threads.
   • Prefer ThreadPoolExecutor for controlled concurrency and error propagation.
   • Use locks to protect invariants; do not rely on the GIL for safety.
   • Use queue.Queue for producer–consumer patterns.
   • For high-concurrency I/O, prefer asyncio and never block the event loop.

10. Robustness and Error Handling
    • Use try/except/else/finally intentionally.
    • Use context managers to encode resource safety and cleanup.
    • Use timezone-aware datetime values explicitly.
    • Define a root exception type for each public API surface.
    • Emit actionable, precise error messages.

11. Typing Discipline (Strict Mode)
    • Type all public functions, methods, and class attributes.
    • Avoid Any except at explicit system boundaries.
    • Use Protocol for structural subtyping.
    • Use TypedDict for structured dictionaries.
    • Use Final, Literal, and TypeAlias where they improve clarity.
    • Treat type changes as breaking API changes.

12. Performance and Maintainability
    • Measure before optimizing.
    • Choose data structures intentionally (deque, heapq, bisect, memoryview).
    • Avoid premature micro-optimizations.
    • Prefer clarity over performance unless profiling proves otherwise.

13. Testing and Long-Term Maintenance
    • Isolate side effects to make code testable.
    • Prefer dependency injection over hard-coded globals.
    • Use repr() for debugging output.
    • Mock boundaries, not internals.
    • Document invariants and assumptions in docstrings.

## Success Criteria

• Code is idiomatic, explicit, and boring in the best sense.
• Types are complete, precise, and enforceable in strict mode.
• Error handling and resource boundaries are explicit.
• Concurrency model is intentional and safe.
• The codebase is readable by a competent Python engineer without explanation.

If something feels clever, rewrite it.

