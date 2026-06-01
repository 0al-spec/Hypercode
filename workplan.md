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
- Rules are **executable specifications** (SpecificationCore): grammar,
  validation and cascade resolution are composable `Specification` /
  `DecisionSpec` objects — the 0AL house style.

## Open decisions

- ✅ **Adopt SpecificationCore** (`github.com/SoundBlaster/SpecificationCore`).
  Decided: grammar, validation and cascade resolution are expressed as composable
  `Specification` / `DecisionSpec` objects. Zero *external* deps still holds —
  SpecificationCore is 0AL's own foundation.
- ✅ **Extract a shared grammar-core**, but **build it here in Hypercode first**,
  then refactor Hyperprompt and Ontology onto it (see M6).
- ✅ **D1 — `.hcs` lexical syntax.** Hand-rolled minimal subset for now; Yams is
  **not** pulled in until we actually consume real YAML input.
- ❓ **D2 — Resolution semantics form.** The SpecificationCore specs *are* the
  executable rules. Open: how much extra prose / fixtures (and, later, Lean) to
  layer on top, and when.

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
- [x] HC-014 Adopt SpecificationCore + seed the `Specifications/` layer (`IdentifierSpec`) — `swift/Sources/Hypercode/Specifications/`

## M2 — Cascade resolution ✅ core (on SpecificationCore)
- [x] HC-020 Resolution semantics — `EBNF/Hypercode_Resolution.md` (operational semantics narrating the executable specs; conformance = `swift/Examples` + `CascadeResolverTests`)
- [x] HC-021 `.hcs` reader → cascade-sheet model (selectors, rules, `@dimension[value]` blocks) — `swift/Sources/Hypercode/HCS/CascadeSheet*.swift`
- [x] HC-022 Selector matching as `Specification`s over nodes: type / `.class` / `#id` / child (`>`) — `HCS/SelectorSpecs.swift`
- [x] HC-023 Specificity + cascade as a `DecisionSpec`: `(specificity, source-order)` → value + provenance — `HCS/Resolver.swift` *(origin/importance deferred until there's syntax for it)*
- [x] HC-024 Context activation: `@dimension[value]` guards (env / client) via `Rule.isActive(in:)`
- [x] HC-025 Resolver: `.hc` + `.hcs` + context → resolved graph with provenance — `HCS/Resolver.swift`
- [x] HC-026 Resolver tests: RFC §5 web-service example (dev + production + provenance), reader & selector tests — `swift/Tests/`
- [x] HC-027 CLI: `hypercode resolve app.hc --hcs config.hcs [--ctx key=value]` — prints the resolved tree with provenance; `swift/Examples/service.{hc,hcs}` — `swift/Sources/HypercodeCLI/`

## M3 — Emit & validation
- [x] HC-030 Generic emit: resolved graph → canonical IR `hypercode.ir/v1` (JSON/YAML), schema-agnostic, hand-rolled — `swift/Sources/Hypercode/Emit/`, CLI `emit`
- [x] HC-031 `hypercode validate`: id uniqueness (.hc) + dangling-selector warnings (.hcs vs .hc) — `swift/Sources/Hypercode/Validation/`, CLI `validate`
- [x] HC-032 Versioned resolved-graph schema (cross-impl contract) + fixtures — `swift/Schema/hypercode-ir-v1.schema.json` *(automated schema-validation in CI deferred)*

## M4 — Consumers & compilation (downstream)
- [ ] HC-040 White-label example end-to-end: one `.hc`, swap `.hcs` → different builds
- [ ] HC-041 Backends/adapters pattern doc: resolved graph → target language/format
- [ ] HC-042 Ontology path (in the **Ontology** repo): `ontologyc import-hypercode` maps resolved graph → DomainOntologyPackage YAML; `--schema` stays consumer-side

## M5 — Formal verification 🅿️
- [ ] HC-050 Lean 4 oracle for the cascade core: executable semantics that generates the fixtures, plus a theorem that the precedence key is a total order ⇒ resolution is deterministic & total. Deferred until the rules stabilize on a working implementation.

## M6 — Shared grammar-core (sequenced: Hypercode first, then refactor consumers)
- [x] HC-060 Canonical `.hc` grammar-core as layered Specifications — `swift/Sources/Hypercode/Specifications/` (Lexical: `IdentifierSpec`; Syntactic: `CommandSpec`, line specs; Decisions: `LineKindDecision`). Indentation stays in the hand-rolled lexer front.
- [ ] HC-061 Reconcile dialect differences with Hyperprompt (quotes / references / paths): core vs dialect extensions
- [ ] HC-062 Refactor Hyperprompt to depend on Hypercode's grammar-core (after it stabilizes)
- [ ] HC-063 Refactor Ontology's Hypercode import path onto the shared grammar-core

## Cross-cutting
- [x] HC-090 Swift CI workflow (build + test) — `.github/workflows/swift.yml`
- [ ] HC-091 Confirm repo layout for the Swift implementation (currently `swift/`)
- [ ] HC-092 Relabel the ANTLR/Java implementation as a conformance oracle once Swift reaches parity
