# HC-110..112 Implementation Plan

Spec-layer hardening: cascade trace (`explain`), monotonic selector contracts, and IR v2.
Companion to [workplan.md](../workplan.md) M8 task stubs and [RFC §9](../RFC/Hypercode.md).

## Confirmed decisions

| ID | Decision |
|---|---|
| D1 | `TypedValue` = union `string/int/double/bool`; inferred at parse time in `CascadeSheetReader.parseProperty` (no new syntax). |
| D2 | Losers retained inside `ResolvedValue` as `losers: [Match]`; public API, because `explain` and IR v2 both need them. |
| D3 | `explain` command address: `<selector> [property]` positional (avoids `Node.prop` ambiguity with class selectors). |
| D4 | ~~SHA-256 without swift-crypto: vendor pure-Swift implementation~~ Superseded 2026-06-11 (R11): use `swift-crypto` — same CryptoKit API, Linux-capable; accepted as the second dependency. Shipped CryptoKit wrapper is interim. |
| D5 | `@contract:` block syntax (fits existing outline-reader mechanics, not `@contract Selector:` which needs new grammar). |

## PR sequence

```
PR-1 substrate  ──▶  PR-2 HC-112 IR v2  ──▶  PR-3 HC-110 explain
                                          ──▶  PR-4 HC-111 contracts (also needs PR-1+PR-2)
```

## PR-1 — Substrate (`feat/hc-112-substrate`, [#19](https://github.com/0al-spec/Hypercode/pull/19) open)

All three features share these foundations; merges first with zero user-visible change.

### TypedValue

New type in `Sources/Hypercode/HCS/`:

```swift
public enum TypedValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}
```

Inference order in `parseProperty`: quoted scalars are always `.string` (quoting
forces string); unquoted scalars try `true`/`false`, then `Int`, then `Double`
(rejected if it contains letters, so `1e5` stays a string), else `.string`.

### Rule gains `file`

```swift
public struct Rule {
    // ...existing fields...
    public let file: String?   // nil = unknown origin (e.g. in-memory tests)
}
```

`CascadeSheetReader.read(_:)` → `read(_:file:)` (optional `String?`), passes `file` into each `Rule`.
Call sites in CLI: pass the `.hcs` path string.

### Match and ResolvedValue

```swift
public struct Match: Equatable, Sendable {
    public let value: TypedValue
    public let selector: Selector
    public let file: String?
    public let line: Int
    public let specificity: Specificity
    public let order: Int
}

public struct ResolvedValue: Equatable, Sendable {
    public let value: TypedValue          // winner's value
    public let provenance: Provenance     // kept for back-compat (selector + file + line)
    public let winner: Match
    public let losers: [Match]            // sorted descending by precedence
}
```

`Provenance` gains `file: String?` (nil for legacy in-memory tests).

### PropertyCascade changes

`decide` sorts all candidates descending, returns winner + all others as `losers`.
Cascade semantics are **unchanged** — only retention of losing matches is added.

### Package bump

`Package.swift` version comment: `0.5.0-dev` *(historical — released as `0.5.0` in [#26](https://github.com/0al-spec/Hypercode/pull/26))*.

---

## PR-2 — HC-112 IR v2 (`feat/hc-112-ir-v2`, [#20](https://github.com/0al-spec/Hypercode/pull/20) open)

Depends on PR-1.

### Schema

New `Schema/hypercode-ir-v2.schema.json`:

```jsonc
{
  "version": "hypercode.ir/v2",
  "context": { /* echo of --ctx flags */ },
  "resolver": { "name": "hypercode-swift", "version": "0.5.0" },
  "documentHash": "<sha256-hex>",   // Merkle root of all node hashes
  "nodes": [{
    "type": "...", "class": "...", "id": "...",
    "hash": "<sha256-hex>",          // over stable JSON of type+class?+id?+properties+childHashes
    "properties": {
      "key": {
        "value": <typed scalar>,
        "winner": { "selector": "...", "file": "...", "line": 42,
                    "specificity": [0,0,1], "order": 0 },
        "losers": [ /* same shape */ ],
        "contracts": []              // filled by PR-4; empty array in v2 base
      }
    },
    "children": [/* recursive */]
  }]
}
```

### CLI

`hypercode emit ... [--ir-version 1|2]` — default v2.
v1 emitter kept intact for `--ir-version 1`.

### Hashing (D4, superseded — see decisions table)

`Sources/Hypercode/Crypto/SHA256.swift` is a thin wrapper over the platform
SHA-256 (CryptoKit in this PR; switched to `swift-crypto` later in the chain
per R11). Test vectors from NIST FIPS 180-4 in `Tests/SHA256Tests.swift`.

Node hash input: deterministic JSON of `{type, class?, id?, properties: {key: value}, childHashes: []}`.
Document hash: SHA-256 of newline-joined root-node hashes in document order.

### CI

Add `ajv` JSON Schema validation step to `.github/workflows/swift.yml`:
validates `Examples/` IR output against `Schema/hypercode-ir-v2.schema.json`.

---

## PR-3 — HC-110 `hypercode explain` (`feat/hc-110-explain`, [#21](https://github.com/0al-spec/Hypercode/pull/21) open)

Depends on PR-1 and PR-2.

### CLI signature

```
hypercode explain <file.hc> --hcs <file.hcs> [--ctx key=value]... <selector> [property]
```

`<selector>`: CSS-like string, e.g. `service`, `.primary`, `#auth`, `service > database`.
`[property]`: optional; if omitted, show all properties for the matched node(s).

### Text output (default)

```
Node: service > database  (matched 1 node)

  pool_size
    WINNER  service > database { pool_size: 20 }
            file: config.hcs  line: 14  specificity: (0,0,2)  order: 1
    ──────
    losing  database { pool_size: 10 }
            file: config.hcs  line: 7   specificity: (0,0,1)  order: 0
```

### JSON output (`--diagnostics json`)

Array of explain records using the `Diagnostic` envelope shape + a new `trace` key.

### Tests

Golden-file tests against `Examples/service.{hc,hcs}` for:
- single property explain (dev context)
- single property explain (production context, different winner)
- node-level explain (all properties)
- no-match selector (non-zero exit, message to stderr)

---

## PR-4 — HC-111 Monotonic contracts (`feat/hc-111-contracts`, [#22](https://github.com/0al-spec/Hypercode/pull/22) open)

Depends on PR-1, PR-2, and PR-3.

### `.hcs` syntax

```hcs
@contract:
  service:
    timeout[?]: int >= 1 <= 300
  .primary:
    replicas: int >= 2
```

`@contract:` is a new outline block (same level as `@dimension[value]`).
Reader recognises the keyword and routes to `parseContractBlock`.

### Constraint grammar

```
constraint  = key ["?"] ":" type [">=" number] ["<=" number]
type        = "string" | "int" | "float" | "bool"
key         = identifier
```

`[?]` = optional (property may be absent). Default: required.

### Monotonicity check (HC-111 normative rule)

Given contracts attached to a selector `S` and an inherited contract from ancestor selector `A`
(where `specificity(S) > specificity(A)`):

- type must be identical (narrowing preserves the type)
- numeric `[min, max]` interval of `S` must be ⊆ interval of `A`
- `required` may not become `optional` (reverse: `optional` → `required` is ok)

Violation = `Diagnostic(severity: .error, code: "HC2101", ...)` → exit 1.

### IR v2 `contracts[]`

Each property entry in v2 IR gains:
```jsonc
"contracts": [
  { "selector": "...", "type": "int", "min": 1, "max": 300, "required": true }
]
```
Accumulated (all applicable contracts, sorted by specificity ascending).

### RFC bump

With this PR: RFC `SPEC-VERSION` → 0.2 (contracts are now in the language model).
Package release: `0.5.0`.
Update `EBNF/Hypercode_Syntax.md` with `.hcs` contract block grammar.

---

## Files touched per PR

| File | PR-1 | PR-2 | PR-3 | PR-4 |
|---|---|---|---|---|
| `Sources/Hypercode/HCS/CascadeSheet.swift` | TypedValue, Match, Rule.file | — | — | Contract types |
| `Sources/Hypercode/HCS/Resolver.swift` | Provenance.file, losers retained | — | — | — (value validation → PR-5, see R9) |
| `Sources/Hypercode/HCS/CascadeSheetReader.swift` | parseProperty types, read(file:) | — | — | @contract: block |
| `Sources/Hypercode/Emit/Emitter.swift` | TypedValue render | v2 emitter | — | contracts in v2 |
| `Sources/HypercodeCLI/main.swift` | pass file to reader | --ir-version flag | explain subcommand | — |
| `Sources/Hypercode/Crypto/SHA256.swift` | — | new | — | — |
| `Schema/hypercode-ir-v2.schema.json` | — | new | — | contracts field |
| `Tests/SHA256Tests.swift` | — | new | — | — |
| `Tests/ExplainTests.swift` | — | — | new | — |
| `Tests/ContractTests.swift` | — | — | — | new |
| `RFC/Hypercode.md` | — | — | — | v0.2 bump |
| `EBNF/Hypercode_Syntax.md` | — | — | — | @contract syntax |

---

## Review follow-ups (strict review 2026-06-11, PR-1..PR-4)

All findings reproduced against `feat/hc-111-contracts` (69a38f0). R1–R8 block merging
[#22](https://github.com/0al-spec/Hypercode/pull/22); R9–R12 need an owner decision first.

### A — Blocking #22

- ✅ **R1 — IR v2 violates its own schema: child nodes have no `hash`.**
  `Emitter.intermediateV2` post-inserts `hash` only into root forest nodes; the schema
  requires it on every `resolvedNode`. Fix: compute/pass the hash inside `nodeV2`
  recursion instead of the zip-insert. Add a nested-document schema-shape test.
- ✅ **R2 — emitter crash on large numerals.** `Emitter.json` `.double` whole-number
  branch does `String(Int(number))`; a 26-digit `.hcs` value parses as `Double(1e26)`
  and traps (`exit 133`). Render without `Int` conversion; add a regression test.
  YAML path is unaffected.
- ✅ **R3 — ContractValidator false positive on disjoint selectors.** Pairs are compared
  purely by specificity; `Service { timeout <= 100 }` vs `.slow { timeout <= 500 }`
  errors (HC2102) even when no node matches both. Gate the pairwise check on
  "∃ node in forest matched by both selectors" — `Validator.validate(_:against:)`
  already has the forest.
- ✅ **R4 — equal-specificity contract conflicts pass silently.** Two `Service:` blocks
  with `timeout: int` vs `timeout: float` produce no diagnostic (guard skips
  `specificity ==`). At minimum flag type conflicts at equal specificity.
- ✅ **R5 — Foundation leak in core.** `Explainer.renderMatch` uses
  `padding(toLength:withPad:startingAt:)` (Foundation/NSString) with no import in file —
  compiles only via Swift 5 leaky member lookup; breaks under `MemberImportVisibility`.
  Hand-roll the padding; core stays Foundation-free.
- ✅ **R6 — compiler warning.** `Explainer.swift:113` `var line1` never mutated → `let`.
- ✅ **R7 — test framework consistency.** `ContractTests.swift` uses Swift Testing;
  the other 14 test files (incl. SHA256/Explain/Emitter tests from this same chain)
  use XCTest. Convert to XCTest (or record a deliberate migration decision).
- ✅ **R8 — undelivered plan items.** Root `workplan.md` M8: HC-110/111/112 still ⬜
  (mark only on merge); `RFC/Hypercode.md` not bumped (PR-4 promised v0.2; §Limitations
  "untyped strings in IR v1" needs a v2 note); IR `contracts[]` not sorted by ascending
  specificity as specified; `Package.swift` `0.5.0-dev` version comment (the pre-release string) missing (PR-1);
  CI `ajv` schema-validation step missing (PR-2); EBNF v0.2: `<scalar>` wrongly requires
  quoted strings (bare `driver: sqlite` is valid), header `Date:` stale, and the HC21xx
  semantics table belongs in `Hypercode_Resolution.md`.

### B — Decided 2026-06-11, pending implementation

- ✅ **R9 — contract value validation was not implemented.** Values were never checked
  against contracts (`timeout: 999` under `int <= 300` passed; wrong-type values passed).
  **Decision:** separate **PR-5** — value validation against contracts with a new
  **HC2104** diagnostic (type mismatch, bounds violation, missing required property).
  #22 stays scoped to grammar + monotonicity; files table fixed (`Resolver` row moved
  to PR-5). **Done:** `ContractValueValidator` on `feat/hc-111-value-validation`;
  `validate` gained `--ctx`; violations point at the winning rule.
- ✅ **R10 — v1 emitter is now lossy for numeric-looking strings.** `version: 1.10` →
  `"1.1"`, `build: 0123` → `"123"` under `--ir-version 1` (regression vs pre-PR-1 raw
  strings). **Decision:** store the source lexeme alongside the typed value; v1 emits
  the lexeme byte-for-byte, v2 keeps typed values. Implement in the open chain before
  merge.
- ✅ **R11 — D4 deviation.** SHA-256 shipped as a CryptoKit wrapper, not the approved
  vendored pure-Swift implementation; core is now Apple-only (no Linux).
  **Decision:** switch to `swift-crypto` (same API surface, Linux-capable); accept it
  as the project's second dependency after SpecificationCore. D4 row updated.
- ✅ **R12 — absent-bound semantics underspecified.** A more-specific contract that
  omits `min`/`max` is not flagged as widening. **Decision:** omitted bound = inherited
  via interval intersection — the effective contract for a node is the intersection of
  all applicable contracts. Current validator behavior is correct; fix is to specify
  this normatively in the RFC contracts section (bundle with the R8 RFC update).
- ✅ **R13 — public API construction gaps.** `Match`, `PropertyTrace`, `NodeTrace` have
  no public inits, so external consumers cannot build `ResolvedValue`; `ResolvedValue`
  duplicates winner data with no invariant. **Decision:** add explicit `public init` to
  all three (project practice) and add `ResolvedValue.init(winner:losers:)` deriving
  `value`/`provenance` from `winner` so inconsistent construction is impossible.
