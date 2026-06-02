# Hypercode — Architecture & Repository Layout

## Components

| Path | Role |
|---|---|
| `RFC/Hypercode.md` | The paradigm RFC (concepts, HCS, cascade) |
| `EBNF/Hypercode_Syntax.md` | Formal `.hc` syntax (BNF) |
| `EBNF/Hypercode_Resolution.md` | Formal cascade resolution semantics |
| `EBNF/` (ANTLR `.g4`, Java, Makefile, `hypercode_tests/`) | **Conformance oracle** for `.hc` parsing |
| `swift/` | **Reference implementation** (Swift + SpecificationCore) |
| `swift/Schema/` | Versioned IR schema (`hypercode.ir/v1`) — the cross-impl contract |
| `swift/Examples/` | Runnable `.hc` / `.hcs` examples (service, white-label) |

## Reference implementation vs oracle (HC-091 / HC-092)

The Swift package under `swift/` is the **reference implementation**: the
canonical grammar-core (as SpecificationCore specifications), the `.hcs` reader,
the cascade resolver, emit/validate, and the `hypercode` CLI.

The ANTLR/Java setup in `EBNF/` predates it and is retained as a **conformance
oracle** for `.hc` parsing — both must agree on `EBNF/hypercode_tests/*.hc`.
New language work happens in `swift/`.

## Dependency direction

Consumers (Ontology, Hyperprompt, …) depend on Hypercode, never the reverse. The
integration contract is the resolved-graph IR (`swift/Schema/`), not the Swift
API: a consumer reads the emitted IR (or links the library) and projects it to
its own target. See [Backends.md](Backends.md) and [Dialects.md](Dialects.md).
