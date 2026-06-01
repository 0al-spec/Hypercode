# Hypercode + ANTLR Playground

This subproject provides a minimal interactive environment for experimenting with the **Hypercode language grammar**, implemented in [ANTLR4](https://www.antlr.org/).

> Use this if you're contributing to the grammar, testing `.hc` files, or building parsers/interpreters for Hypercode.

## Requirements

- Java 11 or later
- [curl](https://curl.se/)
- macOS, Linux or WSL (Makefile-based)

## Quick Start

```bash
git clone https://github.com/0al-spec/Hypercode.git
cd Hypercode/EBNF
make run
```

The first `make run` will automatically:

1. Download `antlr-4.13.0-complete.jar`
2. Generate Java sources from `HypercodeLexer.g4` and `HypercodeParser.g4`
3. Compile the parser and lexer
4. Parse and print the structure of `example.hc`

## 📁 Directory Layout

```
EBNF/
├── HypercodeLexer.g4       # ANTLR4 lexer grammar (tokens, indentation)
├── HypercodeParser.g4      # ANTLR4 parser grammar (commands, blocks)
├── example.hc              # Sample Hypercode input file
├── Main.java               # Parse entry-point for .hc files
├── Makefile                # Build, run, test, clean
├── hypercode_tests/        # Test suite for the grammar
├── .gitignore              # Ignores generated files
```

## Available Commands

```bash
make             # download JAR, build and run parser on example.hc
make run         # re-run Main.java with example.hc
make test-all    # run all grammar tests in hypercode_tests/
make clean       # remove generated files
```

To run a different file:

```bash
make run EXAMPLE=hypercode_tests/03-nesting.hc
```

## Development Notes

- Grammar is split into **HypercodeLexer.g4** and **HypercodeParser.g4**
- Indentation is handled via custom Java logic in `nextToken()` (see `@members`)
- Tokens `INDENT` and `DEDENT` are inserted based on change in indentation level
- The parser entry point is `hypercode`
- Output is generated via `Main.java` — a minimal runtime for inspection

## License

This directory is part of the [Hypercode project](https://github.com/0AL-spec/Hypercode) and licensed under MIT.
