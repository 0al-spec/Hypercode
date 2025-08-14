# `CHANGELOG.md`

## Hypercode Change Log

All notable changes to the **Hypercode language** will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [0.3.0]

### Added

- `INDENT/DEDENT` support with stack logic
- `Main.java` entry point for parser testing
- CI badge for `make test-all`

### Changed

- Grammar split into `HypercodeLexer.g4` and `HypercodeParser.g4`
- Test runner uses `Main.java` instead of TestRig

### Deprecated

- Old monolithic `Hypercode.g4` (removed in next release)

## [0.2.0] – 2025-07-15

Initial public release:
- BNF-style syntax for `.hc`
- ANTLR 4 grammar
- Makefile support
- `make test-all` with 10 test cases
- RFC draft in `docs/RFC.md`
