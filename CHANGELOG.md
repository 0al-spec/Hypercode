# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased] — 0.6.0-dev

### Added
- `@import "path.hcs"` for cascade sheets (HC-116): depth-first expansion at
  the directive position (the importer wins specificity ties), import-once
  for diamonds, cycle detection, cross-file provenance; contracts compose
  across imports. `ImportHandling` API (`.unsupported`/`.syntaxOnly`/`.loader`).
- Runtime resolver boundary decision record (HC-114): build/generation-time
  resolution remains the supported mode for the reference implementation;
  embedded runtime resolution is out of scope with explicit revisit conditions,
  and HC-115 (OpenFeature bridge) is parked.
- Kustomize comparison demo (HC-120): a 3 tenants x 3 environments example
  modeled both as Kustomize overlays and as Hypercode sheets, with CI metrics
  for source files, meaningful lines, duplicated lines, and validation of all
  9 tenant/environment targets.
- Ontology backend dogfooding example (HC-121): the real `examcalc`
  DomainOntologyPackage modeled as Hypercode and regenerated from IR v2 by a
  consumer-side Python adapter; CI checks semantic equality against the
  original YAML and records the first dogfooding friction log (F1-F5).
- HC-121 consumer closure notes: Ontology's `ontologyc import-hypercode`
  consumes ontology-shaped IR v2 as real `DomainOntologyPackage` sections while
  preserving draft-only governance, and Hyperprompt has a runnable
  core-Hypercode compile-configuration exercise.
- RFC §10 backlog contracts: `DOCS/IntegrityChain.md` for HC-122 and
  `DOCS/TypeSystemDepth.md` for HC-125/HC-126, turning the remaining integrity
  chain and richer-type questions into explicit acceptance criteria.

### Changed
- `@import` trust model and library identity contract are documented: the CLI
  loader is for trusted local configuration, embedders resolving untrusted
  sheets must provide a policy-bound `ImportHandling.loader`, and
  `CascadeSheetReader.read(file:imports:)` requires the entry file identity to
  use the same canonical scheme as loader-returned identities.
- Ontology backend validation is stricter: duplicate top-level sections and
  duplicate class/relation/policy/state-machine/field ids now fail with a clear
  `malformed package` error instead of silently overwriting earlier entries.
- Demo Python helpers use explicit UTF-8 file/subprocess boundaries where they
  read generated IR, YAML fixtures, and source trees.

## [0.5.0] — 2026-06-12

Spec-layer hardening: the resolver becomes a verifiable pipeline — typed IR
with full provenance, monotonic contracts, cascade explanation, semantic diff,
and a runnable AI-codegen loop. (PRs
[#19](https://github.com/0al-spec/Hypercode/pull/19)–[#25](https://github.com/0al-spec/Hypercode/pull/25).)

### Added
- **`hypercode.ir/v2`** (HC-112, breaking; now the default `emit` output):
  typed values (int/float/bool/string instead of strings-only), the winning
  rule *and* every losing rule per property with `file:line`, specificity and
  source order, applicable contracts echoed per property, per-node SHA-256
  Merkle hashes over the stable resolved content plus a `documentHash`,
  context echo, and `resolver.name`/`version`. JSON Schema in `Schema/`;
  v1 remains available via `--ir-version 1`.
- **Monotonic selector contracts** (HC-111): `@contract:` blocks in `.hcs`
  attach property schemas (type, bounds, required) to selectors. Values
  cascade; contracts accumulate by intersection and may only narrow —
  weakening an inherited contract is a build error (RFC §9.4, normative).
  Diagnostics HC2101–HC2103, plus context-dependent value validation HC2104
  (`validate --ctx`): a production override that violates a bound fails the
  build instead of shipping.
- **`hypercode explain <selector> [property]`** (HC-110) — the full cascade
  trace: why a value is what it is, the winner and every loser with
  specificity and source order.
- **`hypercode diff <old.ir> <new.ir>`** (HC-113) — semantic diff over IR v2:
  hash-driven (unchanged subtrees skipped), selector-identity node matching
  with content-hash pairing for duplicate siblings, added/removed/modified/
  reordered changes with old/new winning rules. `--format json` emits
  `hypercode.diff/v1` (schema in `Schema/`); exit codes 0/1/2 (`diff`-like).
- **End-to-end AI codegen demo** (HC-124, `Examples/codegen-demo/`): spec →
  IR v2 → one generated Python module per node with embedded node hash and
  per-value provenance; `check.py` verifies freshness (node hashes) and
  contract conformance of the artifacts (required/bounds/type/drift);
  `generate.sh` regenerates only stale modules via Claude. Runs in CI.
- **Usage guide** (`DOCS/Usage.md`) with real CLI outputs for every command;
  `OVERVIEW.md` rewritten to the current positioning (context-resolved
  specification layer). RFC v0.2; `.hcs` grammar and resolution semantics
  formalized in `EBNF/` 0.2.
- CI validates emitted IR and diff output against their JSON Schemas (ajv).

### Changed
- SHA-256 via **swift-crypto** instead of CryptoKit (Linux-capable).
- Hardened boundaries: emitted JSON escapes object keys; `--ctx` keys must be
  identifiers; the diff JSON parser is strict RFC 8259 (number grammar,
  control characters); unreadable `diff` input exits 2, never 1.
- Single version constant `HypercodeVersion.current`, echoed as
  `resolver.version` in IR v2.

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
