# ``Hypercode``

A declarative architectural language: `.hc` structure plus `.hcs` cascade
sheets, resolved into a graph with provenance.

## Overview

Hypercode separates a program's **structure** (`.hc`) from its **context**
(`.hcs` — cascading sheets, like CSS for structure). The same structure resolves
to different outputs by swapping the context, without ever touching the `.hc`.

```
.hc + .hcs ──[resolve]──▶ resolved graph ──[emit]──▶ canonical IR (hypercode.ir/v1)
```

The library provides the lexer and parser, the grammar expressed as
SpecificationCore specifications, the cascade resolver (selectors, specificity,
context), plus validation and emit. The `hypercode` CLI exposes `parse`,
`validate`, `resolve`, and `emit`.

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

Or emit the canonical IR (`hypercode.ir/v1`) for a downstream consumer:

```bash
hypercode emit app.hc --hcs app.hcs --ctx env=production --format json
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

### Emit & validation

- ``Emitter``
- ``EmitFormat``
- ``Validator``
- ``Diagnostic``
- ``Severity``

### Grammar specifications

- ``IdentifierSpec``
- ``CommandSpec``
- ``IsBlankLineSpec``
- ``ValidCommandLineSpec``
- ``LineKindDecision``
- ``RawLine``
- ``LineKind``
