# Hypercode

A declarative architectural language: separate a program's **structure** (`.hc`)
from its **context** (`.hcs` — cascading sheets, like CSS for structure), then
resolve them into a graph with provenance. Swap the context to get a different
build **without touching the structure**.

📖 **API documentation:** <https://0al-spec.github.io/Hypercode/>

```
.hc + .hcs ──[resolve]──▶ resolved graph ──[emit]──▶ canonical IR (hypercode.ir/v1)
```

## Why

- **Separation of concerns** — `.hc` is the *what* (structure / intent); `.hcs`
  is the *how* (values, configuration), targeted by CSS-like selectors and
  context-aware `@rules`.
- **Context switching / white-label** — one structure, many contexts. Swap
  `--ctx env=production` (or `client=acme`) → different output, same `.hc`.
- **Provenance** — every resolved value records the selector and source line it
  came from.

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
hypercode validate <file.hc> [--hcs <file.hcs>]
hypercode resolve  <file.hc> --hcs <file.hcs> [--ctx key=value]...
hypercode emit     <file.hc> [--hcs <file.hcs>] [--ctx key=value]... [--format json|yaml]
```

The same structure, two contexts:

```bash
hypercode resolve Examples/service.hc --hcs Examples/service.hcs                    # development
hypercode resolve Examples/service.hc --hcs Examples/service.hcs --ctx env=production
```

## Documentation

- **API docs (DocC):** <https://0al-spec.github.io/Hypercode/>
- [Conceptual overview](OVERVIEW.md)
- [RFC — the paradigm](RFC/Hypercode.md)
- Formal specs: [`.hc` syntax (BNF)](EBNF/Hypercode_Syntax.md) · [resolution semantics](EBNF/Hypercode_Resolution.md)
- Architecture: [overview](DOCS/Architecture.md) · [backends & adapters](DOCS/Backends.md) · [core vs dialects](DOCS/Dialects.md)
- [Resolved-graph IR schema](Schema/hypercode-ir-v1.schema.json) — the cross-implementation contract
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
