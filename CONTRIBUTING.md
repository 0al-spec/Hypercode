# Contributing to Hypercode

Hypercode is both a **specification** (RFC, formal grammar & semantics) and a
**Swift reference implementation**. Most code changes go to the implementation;
language changes start in the specs.

## Build & test

```bash
swift build
swift test          # the reference implementation
```

Optional oracles:

- **ANTLR conformance oracle** (`.hc` parsing): `make -C EBNF test-all` (needs Java).
- **Lean cascade oracle**: `cd SPEC/lean && lake build` (needs the Lean toolchain).

## Conventions

- Grammar, validation, and cascade rules are **SpecificationCore** specifications
  (`Specification` / `DecisionSpec`) — the 0AL house style. New rules follow it.
- Keep **core minimal**: practical / domain features belong in consumer dialects,
  not in core `.hc` (see [DOCS/Dialects.md](DOCS/Dialects.md)).
- New behavior needs tests. Resolver changes should keep the conformance fixtures
  and the Lean oracle in agreement.

## Layout & docs

See the [README](README.md#layout), the [architecture overview](DOCS/Architecture.md),
and the [work plan](workplan.md).

## Pull requests

Branch from `main`, keep PRs focused, and make sure `swift test` is green. CI runs
build + tests, the grammar tests, and the DocC build on every PR.
