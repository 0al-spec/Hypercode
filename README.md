# Hypercode
Declarative programming paradigm for context-aware systems

## RFC / Specification

- [RFC: Hypercode — A Declarative Paradigm for Context-Aware Programming](RFC/Hypercode.md) — Draft specification (concepts, syntax, HCS cascading model, examples). Read this to understand the language goals, selectors, contextual `@rules`, and execution model.

## Conceptual Overview

- [Hypercode Conceptual Overview](OVERVIEW.md) — High-level explanation of Hypercode's purpose, the relationship between .hc and .hcs files, division of responsibilities, execution model, cascade semantics, and how Hypercode relates to other tools and languages.

## Subprojects

- [EBNF / ANTLR Playground](EBNF/README.md) — A minimal interactive environment for experimenting with the Hypercode grammar (ANTLR4). Contains the lexer/parser grammars, example `.hc` files, build/run Makefile and tests. See `EBNF/README.md` for requirements and quick-start instructions.

## License

- Specifications & Documents (in `DOCS/`, `RFC/`) are licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0).
- Source Code (in `EBNF/`) is licensed under the MIT License.

See [LICENSE](./LICENSE) and [LICENSE-CC-BY-4.0](./LICENSE-CC-BY-4.0) for details.
