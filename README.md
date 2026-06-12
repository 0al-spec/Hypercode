# Hypercode

A declarative architectural language: separate a program's **structure** (`.hc`)
from its **context** (`.hcs` — cascading sheets, like CSS for structure), then
resolve them into a graph with provenance. Swap the context to get a different
build **without touching the structure**.

📖 **API documentation:** <https://0al-spec.github.io/Hypercode/>

```
.hc + .hcs ──[resolve]──▶ resolved graph ──[validate contracts]──▶ canonical IR (hypercode.ir/v2)
```

## Why

- **Separation of concerns** — `.hc` is the *what* (structure / intent); `.hcs`
  is the *how* (values, configuration), targeted by CSS-like selectors and
  context-aware `@rules`.
- **Context switching / white-label** — one structure, many contexts. Swap
  `--ctx env=production` (or `client=acme`) → different output, same `.hc`.
- **Provenance** — every resolved value records the selector, file and source
  line it came from; `hypercode explain` shows the winner *and* every losing rule.
- **Contracts that only narrow** — `@contract:` blocks attach invariants to
  selectors; values cascade, safety doesn't. A production override that breaks
  a bound is a build error (`HC2104`), not an incident.
- **Hashed, typed IR** — per-node SHA-256 over stable resolved content: the
  invalidation signal for incremental (re)generation.

## Install

### CLI

```bash
git clone https://github.com/0al-spec/Hypercode
cd Hypercode
swift build -c release
.build/release/hypercode --help
```

…or run without installing:

```bash
swift run hypercode resolve Examples/service.hc --hcs Examples/service.hcs --ctx env=production
```

### Library (SwiftPM)

```swift
.package(url: "https://github.com/0al-spec/Hypercode", from: "0.4.0"),
// then, as a target dependency:
.product(name: "Hypercode", package: "Hypercode"),
```

## CLI

```
hypercode parse    <file.hc>
hypercode validate <file.hc> [--hcs <file.hcs>] [--ctx key=value]...   # incl. contract checks
hypercode resolve  <file.hc> --hcs <file.hcs> [--ctx key=value]...
hypercode emit     <file.hc> [--hcs <file.hcs>] [--ctx key=value]... [--format json|yaml] [--ir-version 1|2]
hypercode explain  <file.hc> --hcs <file.hcs> [--ctx key=value]... <selector> [property]
hypercode diff     <old.ir.json> <new.ir.json> [--format text|json]    # affected nodes, exit 1 on change
hypercode lsp                                                          # LSP over stdio
```

The same structure, two contexts:

```bash
hypercode resolve Examples/service.hc --hcs Examples/service.hcs                    # development
hypercode resolve Examples/service.hc --hcs Examples/service.hcs --ctx env=production
```

## Documentation

- **[Usage guide](DOCS/Usage.md)** — every command with real outputs: contexts, contracts, explain, IR v2
- **API docs (DocC):** <https://0al-spec.github.io/Hypercode/>
- [Conceptual overview](OVERVIEW.md)
- [RFC — the paradigm](RFC/Hypercode.md)
- Formal specs: [`.hc` syntax (BNF)](EBNF/Hypercode_Syntax.md) · [resolution semantics](EBNF/Hypercode_Resolution.md)
- Architecture: [overview](DOCS/Architecture.md) · [backends & adapters](DOCS/Backends.md) · [core vs dialects](DOCS/Dialects.md) · [positioning](DOCS/Positioning.md)
- Resolved-graph IR schemas — the cross-implementation contract: [v2](Schema/hypercode-ir-v2.schema.json) · [v1 (legacy)](Schema/hypercode-ir-v1.schema.json)
- [Lean 4 cascade oracle](SPEC/lean/) — machine-checked agreement with the resolver
- [Work plan](workplan.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

## Layout

| Path | What |
|---|---|
| `Sources/`, `Tests/`, `Package.swift` | Swift reference implementation (built on [SpecificationCore](https://github.com/SoundBlaster/SpecificationCore)) |
| `Examples/` | Runnable `.hc` / `.hcs` (service, white-label) |
| `Schema/` | Versioned IR schema |
| `RFC/`, `EBNF/*.md`, `DOCS/` | Specification & documents |
| `EBNF/` (ANTLR / Java) | Conformance oracle for `.hc` parsing |
| `SPEC/lean/` | Lean 4 cascade oracle |

## License

- Specifications & documents (`RFC/`, `DOCS/`, `EBNF/*.md`) — CC BY 4.0.
- Source code (`Sources/`, `Tests/`, `EBNF/` ANTLR/Java, `SPEC/`) — MIT.

See [LICENSE](LICENSE) and [LICENSE-CC-BY-4.0](LICENSE-CC-BY-4.0).
