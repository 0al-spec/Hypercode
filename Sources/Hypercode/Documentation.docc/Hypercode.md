# ``Hypercode``

A declarative architectural language: `.hc` structure plus `.hcs` cascade
sheets, resolved into a graph with provenance.

## Overview

Hypercode separates a program's **structure** (`.hc`) from its **context**
(`.hcs` — cascading sheets, like CSS for structure). The same structure resolves
to different outputs by swapping the context, without ever touching the `.hc`.

```
.hc + .hcs ──[resolve]──▶ resolved graph ──[validate contracts]──▶ canonical IR (hypercode.ir/v2)
                                                                        │
                                              explain (cascade trace) · diff (affected nodes)
```

The library provides the lexer and parser, the grammar expressed as
SpecificationCore specifications, the cascade resolver (selectors, specificity,
context), contract validation (monotonicity and value-level checks), the
cascade trace (``Explainer``), the typed/hashed IR v2 emitter, and the
semantic IR diff (``IRDiffer``). The `hypercode` CLI exposes `parse`,
`validate`, `resolve`, `emit`, `explain`, `diff`, and `lsp`.

See also: the [resolution semantics](https://github.com/0al-spec/Hypercode/blob/main/EBNF/Hypercode_Resolution.md)
and the [architecture overview](https://github.com/0al-spec/Hypercode/blob/main/DOCS/Architecture.md).

## Usage

Given a structure and a cascade sheet:

```
# app.hc
Service
  Logger.console
  Database#main-db
```

```
# app.hcs
Logger:
  level: "debug"
.console:
  format: "text"

@env[production]:
  Logger:
    level: "info"
```

Resolve them — the printed tree tags each value with the selector it came from
(provenance), and swapping the context changes the result without touching the
`.hc`:

```bash
$ hypercode resolve app.hc --hcs app.hcs
Service
  Logger (class: console)
    - format: text   [.console]
    - level: debug   [Logger]
  Database (id: main-db)

$ hypercode resolve app.hc --hcs app.hcs --ctx env=production
# …level is now "info   [Logger]"
```

Or emit the canonical IR (`hypercode.ir/v2` — typed values, per-node hashes,
cascade trace, contracts) for a downstream consumer:

```bash
hypercode emit app.hc --hcs app.hcs --ctx env=production --format json
```

Ask the cascade *why* a value won, or diff two resolved documents to get the
affected-node set for incremental regeneration:

```bash
hypercode explain app.hc --hcs app.hcs --ctx env=production Logger level
hypercode diff old.ir.json new.ir.json
```

## Topics

### Parsing

- ``Command``
- ``Parser``
- ``Lexer``
- ``Token``
- ``ParseError``
- ``LexError``

### Cascade resolution

- ``Selector``
- ``Specificity``
- ``CascadeSheet``
- ``Rule``
- ``ContextGuard``
- ``CascadeSheetReader``
- ``Resolver``
- ``ResolutionContext``
- ``ResolvedNode``
- ``ResolvedValue``
- ``Provenance``
- ``NodeContext``

### Contracts

- ``ContractType``
- ``PropertyContract``
- ``SelectorContract``
- ``ContractValidator``
- ``ContractValueValidator``

### Explain

- ``Explainer``
- ``NodeTrace``
- ``PropertyTrace``
- ``Match``

### Emit & validation

- ``Emitter``
- ``EmitFormat``
- ``EmitVersion``
- ``Validator``
- ``Diagnostic``
- ``Severity``

### Semantic diff

- ``IRDiffer``
- ``IRChange``
- ``PropertyDiff``
- ``IRDocument``
- ``IRNode``
- ``IRProperty``
- ``JSONParser``
- ``JSONValue``

### Grammar specifications

- ``IdentifierSpec``
- ``CommandSpec``
- ``IsBlankLineSpec``
- ``ValidCommandLineSpec``
- ``LineKindDecision``
- ``RawLine``
- ``LineKind``
