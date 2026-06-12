# Using Hypercode

A practical walkthrough of the toolchain, end to end. Every output below is
real — produced by the CLI from [`Examples/service.hc`](../Examples/service.hc)
and [`Examples/service.hcs`](../Examples/service.hcs).

```
.hc + .hcs + --ctx ──▶ resolve ──▶ validate (contracts) ──▶ emit (IR v2) ──▶ your generator
                          │                                      │
                       explain (why is this value X?)         diff (what changed?)
```

## The running example

One structure, two contexts. `service.hc` is the *what*:

```hypercode
Service
  Logger.console
  Database#main-db
    Connect
  APIServer
    Listen
```

`service.hcs` is the *how* — defaults, a production override block, and
invariants the cascade must respect in **every** context:

```hcs
Logger:
  level: "debug"

APIServer > Listen:
  host: "127.0.0.1"
  port: 5000

@env[production]:
  Logger:
    level: "info"
  '#main-db':
    driver: "postgres"
    pool_size: 50
  APIServer > Listen:
    host: "0.0.0.0"
    port: 8080

@contract:
  APIServer > Listen:
    port: int >= 1 <= 65535
    host: string
  '#main-db':
    pool_size[?]: int >= 1 <= 100
```

## 1. One structure, many builds (white-label / environments)

```console
$ hypercode resolve Examples/service.hc --hcs Examples/service.hcs --ctx env=production
Service
  Logger (class: console)
    - format: json   [.console]
    - level: info   [Logger]
  Database (id: main-db)
    - driver: postgres   [#main-db]
    - file: dev.sqlite3   [Database]
    - pool_size: 50   [#main-db]
    Connect
  APIServer
    Listen
      - host: 0.0.0.0   [APIServer > Listen]
      - port: 8080   [APIServer > Listen]
```

Drop `--ctx` and the same structure resolves to the development build
(`sqlite`, `127.0.0.1:5000`, `level: debug`). The `.hc` never changes — that
is the white-label guarantee. Every value carries `[the selector that won]`.

## 2. Guardrails: contracts as a CI gate

Contracts are invariants attached to selectors. Values cascade freely;
contracts only accumulate and narrow (RFC §9.4). Two layers of checking:

**Sheet-level (static):** a more specific contract that *weakens* an inherited
one — wider interval (HC2102), changed type (HC2101), required→optional
(HC2103) — is rejected when the sheet is read.

**Value-level (per context):** the resolved values are checked against every
applicable contract — type, bounds, required presence (HC2104):

```console
$ hypercode validate app.hc --hcs app.hcs --ctx env=production
app.hcs:1:1: error[HC2104]: contract violation for 'port': 99999 exceeds upper bound 65535.0 from contract 'APIServer > Listen'
$ echo $?
1
```

The classic failure — "the production override accidentally weakened a limit" —
becomes a build error instead of an incident. The CI recipe is one line per
context:

```yaml
- name: Validate configuration for every context
  run: |
    hypercode validate app.hc --hcs app.hcs                       # development
    hypercode validate app.hc --hcs app.hcs --ctx env=production
    hypercode validate app.hc --hcs app.hcs --ctx env=staging
```

Diagnostics are also available LSP-shaped: `--diagnostics json`.

## 3. Debugging the cascade: `explain`

"Why is this value X in production?" — the eternal archaeology of layered
configuration, answered in one command:

```console
$ hypercode explain Examples/service.hc --hcs Examples/service.hcs --ctx env=production Logger level
Matched 1 node for selector 'Logger'

Node: Service > Logger.console
  level
    WINNER   Logger { value: info }
             file: Examples/service.hcs  line: 16  specificity: (0,0,1)  order: 4
    ────────────────────
    losing   Logger { value: debug }
             file: Examples/service.hcs  line: 1  specificity: (0,0,1)  order: 0
```

Winner *and* every losing rule, each with its file, line, specificity and
source order. Selectors work the same as in sheets: `Logger`, `.console`,
`'#main-db'`, `APIServer > Listen`. Omit the property to trace all of them.

## 4. Machine-readable output: IR v2

`emit` produces the canonical resolved-graph IR — the contract between
Hypercode and any consumer ([schema](../Schema/hypercode-ir-v2.schema.json),
ajv-validated in CI):

```console
$ hypercode emit Examples/service.hc --hcs Examples/service.hcs --ctx env=production --format json
```

```jsonc
{
  "version": "hypercode.ir/v2",
  "context": { "env": "production" },          // echo of --ctx
  "resolver": { "name": "hypercode-swift", "version": "0.5.0-dev" },
  "documentHash": "3be098179523f21c…",
  "nodes": [ /* … each node: */
    {
      "type": "Listen",
      "hash": "c4ba5d08dcfca81b…",             // stable content hash
      "properties": {
        "port": {
          "value": 8080,                        // typed, not stringly
          "winner":  { "selector": "APIServer > Listen", "line": 26, "specificity": [0,0,2], "…": "…" },
          "losers":  [ { "value": 5000, "line": 11, "…": "…" } ],
          "contracts": [ { "selector": "APIServer > Listen", "type": "int", "min": 1.0, "max": 65535.0, "required": true } ]
        }
      }
    }
  ]
}
```

What each piece is for:

- **Typed values** — consumers get `8080`, not `"8080"`.
- **`hash`** covers only the *stable resolved content* (type/class/id, values,
  child hashes). A different rule winning with the same value does **not**
  change the hash — it is the invalidation signal for incremental
  regeneration: re-generate only nodes whose hashes changed.
- **`winner` / `losers`** — full provenance; an auditor or codegen validator
  can state *which rule* demanded a behavior.
- **`contracts`** — every contract governing the property, ascending
  specificity, so a consumer can re-derive the effective constraint without
  re-parsing the sheet.

`--ir-version 1` keeps the legacy strings-only v1 for existing consumers;
v1 values round-trip byte-for-byte (`1.10` stays `1.10`).

## 5. The target pipeline: specification for AI code generation

The intended role ([RFC §9.7](../RFC/Hypercode.md)): `.hc`/`.hcs` is the durable
specification, code is regenerated output.

```
.hc + .hcs ──▶ resolved IR ──▶ LLM generates code per node
                  │                       │
              node hashes          validated against the same
            (what changed?)        contracts + provenance
```

- The generator consumes the IR — never the raw sheets — so it sees one
  unambiguous, typed, context-resolved graph.
- Node hashes scope regeneration to what actually changed.
- Contracts give the validator formal grounds to reject a generated artifact.
- Humans review the *specification diff*; machines expand it into code
  (review compression).

This loop is runnable today: [`Examples/codegen-demo/`](../Examples/codegen-demo/)
generates a module per node, verifies freshness by node hash and contract
conformance of the generated values in CI. `hypercode diff` (§6) is the
productized form of that hash comparison.

## 6. Semantic diff: `hypercode diff`

The invalidation signal as a first-class command (HC-113). Emit two IRs,
diff them — the output is the affected-node set with reasons:

```console
$ hypercode emit app.hc --hcs app.hcs --ctx env=production > old.ir.json
$ sed 's/port: 8080/port: 9090/' app.hcs > edited.hcs
$ hypercode emit app.hc --hcs edited.hcs --ctx env=production > new.ir.json
$ hypercode diff old.ir.json new.ir.json
~ Service > APIServer > Listen
    ~ port: 8080 → 9090
          was: APIServer > Listen @ app.hcs:26
          now: APIServer > Listen @ edited.hcs:26

1 affected node(s)
$ echo $?
1
```

- Hash-driven: unchanged subtrees are skipped wholesale, so cost is
  proportional to the change, not the tree. A provenance-only change (a
  different rule winning the same value) is invisible — by design.
- **Resolved content only.** Document metadata (`context`, `resolver`) does
  not participate: two IRs that resolve to the same graph under different
  contexts are *identical* (exit `0`) — same graph means nothing to
  regenerate, whichever context produced it. When the contexts differ, the
  text output says so in a leading `note:` line.
- Nodes are matched by selector identity (`type[.class][#id]`); duplicate
  siblings pair by content hash first, so a duplicate that merely moved is a
  reorder, not two modifications. Added, removed and reordered nodes are
  reported as such.
- `--format json` emits `hypercode.diff/v1`
  ([schema](../Schema/hypercode-diff-v1.schema.json), ajv-validated in CI) —
  the machine-readable feed for incremental regeneration (feed it to your
  generator instead of re-running everything).
- Exit code is `diff`-like: `0` identical, `1` documents differ, `2` trouble
  (unreadable or non-v2 input) — usable as a CI gate
  ("spec changed → require regeneration").

## Scalar typing cheat-sheet

| Written in `.hcs` | Resolved as |
|---|---|
| `port: 8080` | int `8080` |
| `ratio: 0.5` | float `0.5` |
| `active: true` | bool `true` |
| `driver: sqlite` | string `"sqlite"` (bare strings are fine) |
| `zip: "00123"` | string `"00123"` — **quoting forces string** |
| `version: 1.10` | float `1.1` in v2; v1 IR preserves the lexeme `1.10` |
