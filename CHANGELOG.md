# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/).

## [0.4.0] — 2026-06-02

First release with a **reference implementation**.

### Added
- Swift package (at the repo root): `.hc` lexer + recursive-descent parser →
  `Command` AST; the grammar-core expressed as SpecificationCore specifications.
- Cascade resolver: `.hcs` reader, selector matching, specificity + cascade as a
  `DecisionSpec`, and a resolved graph with provenance (RFC §4.2).
- `hypercode` CLI: `parse`, `validate`, `resolve`, `emit` (JSON/YAML IR).
- Canonical IR `hypercode.ir/v1` and its JSON Schema (`Schema/`).
- Runnable examples: `service` (RFC §5) and `whitelabel`.
- Formal resolution semantics (`EBNF/Hypercode_Resolution.md`).
- Lean 4 cascade oracle (`SPEC/lean/`) — machine-checked agreement with the
  Swift resolver, plus a totality theorem.
- DocC API documentation deployed to GitHub Pages.
- Architecture documents (`DOCS/Architecture.md`, `Backends.md`, `Dialects.md`).

### Changed
- The Swift package now lives at the repo root and is consumable as a remote
  SwiftPM dependency and releasable via git tags.
- `.hc` syntax spec: the `<block>` rule now uses `INDENT` / `DEDENT`.

## [0.3.0] — 2025-08-14

Specification / RFC milestone, before the implementation: the Hypercode RFC, the
`.hc` BNF syntax specification, and the ANTLR grammar with tests.
