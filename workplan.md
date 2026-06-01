# Hypercode — Work Plan

Status snapshot and task backlog for the Hypercode language (`.hc`) and its
cascade sheets (`.hcs`). Companion to the [RFC](RFC/Hypercode.md) and the
[syntax spec](EBNF/Hypercode_Syntax.md).

**Legend:** ✅ done · 🔜 in progress / next · ⬜ planned · 🅿️ deferred · ❓ decision needed

## Guiding invariants

- `.hc` stays deliberately **simpler than YAML**: structure / intent only, no values.
- Values and context live in `.hcs`; swapping `.hcs` must **never** require touching
  `.hc` (white-label).
- Source of truth = `.hc` + `.hcs`. Any YAML/JSON output is a **generated artifact**,
  not a source.
- The **resolved graph** is the contract between Hypercode and any consumer.
  Consumers (Ontology, …) depend on Hypercode, never the reverse.
- Target-specific compilation (DomainOntologyPackage, Terraform, …) is
  **consumer-owned**, downstream of the resolved graph.

## Open decisions

- ❓ **D1 — `.hcs` syntax.** Proposed: hand-rolled minimal YAML-subset parser
  (zero deps, like `.hc`). Alternative: depend on Yams (full YAML).
- ❓ **D2 — Resolver order.** Proposed: formal resolution semantics + fixtures
  first, then implement against them. Alternative: code-first, formalize after.

## M0 — Spec foundation
- [x] HC-001 `.hc` BNF syntax spec, incl. INDENT/DEDENT block rule — `EBNF/Hypercode_Syntax.md` *(PR #5, open)*
- [x] HC-002 ANTLR reference grammar + `.hc` test suite — `EBNF/`
- [x] HC-003 CI running the grammar tests — `.github/workflows/ci.yml` *(PR #5, open)*
- [ ] HC-004 Merge PR #5 into `main`

## M1 — Swift reference implementation: parsing ✅
- [x] HC-010 `.hc` lexer with indent/dedent (off-side rule) — `swift/Sources/Hypercode/Lexer.swift`
- [x] HC-011 `.hc` recursive-descent parser → `Command` AST — `swift/Sources/Hypercode/Parser.swift`
- [x] HC-012 `hypercode` CLI: parse + print tree — `swift/Sources/HypercodeCLI/`
- [x] HC-013 Lexer/parser tests ported from fixtures (15 green) — `swift/Tests/`

## M2 — Cascade resolution 🔜
- [ ] HC-020 Formal resolution semantics `Hypercode_Resolution.md` (specificity algebra, selector matching, cascade merge, `@rules`/context) + conformance fixtures *(gated by D2)*
- [ ] HC-021 `.hcs` parser → cascade-sheet model (selectors, rules, `@env[…]` blocks) *(gated by D1)*
- [ ] HC-022 Selector matching: type / `.class` / `#id` / child (`>`)
- [ ] HC-023 Specificity + cascade merge: `#id` > `.class` > `type`, source order, origin/importance
- [ ] HC-024 Context activation: `@env[…]` / `client[…]` (white-label)
- [ ] HC-025 Resolver: `.hc` + `.hcs` + context → resolved graph (with provenance)
- [ ] HC-026 Resolver tests against the conformance fixtures
- [ ] HC-027 CLI: `hypercode resolve app.hc --hcs config.hcs [--ctx env=production]`

## M3 — Emit & validation
- [ ] HC-030 Generic emit: resolved graph → canonical IR (YAML/JSON), schema-agnostic, marked generated
- [ ] HC-031 `hypercode validate`: syntax + selector validity + id uniqueness + cascade conflicts + provenance report
- [ ] HC-032 Versioned resolved-graph schema (the cross-impl contract) + valid/invalid fixtures

## M4 — Consumers & compilation (downstream)
- [ ] HC-040 White-label example end-to-end: one `.hc`, swap `.hcs` → different builds
- [ ] HC-041 Backends/adapters pattern doc: resolved graph → target language/format
- [ ] HC-042 Ontology path (in the **Ontology** repo): `ontologyc import-hypercode` maps resolved graph → DomainOntologyPackage YAML; `--schema` stays consumer-side

## M5 — Formal verification 🅿️
- [ ] HC-050 Lean 4 oracle for the cascade core: executable semantics that generates the fixtures, plus a theorem that the precedence key is a total order ⇒ resolution is deterministic & total. Deferred until the rules stabilize on a working implementation.

## Cross-cutting
- [ ] HC-090 Swift CI workflow (build + test on PR)
- [ ] HC-091 Confirm repo layout for the Swift implementation (currently `swift/`)
- [ ] HC-092 Relabel the ANTLR/Java implementation as a conformance oracle once Swift reaches parity
