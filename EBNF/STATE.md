# ANTLR Playground State Report

## Summary
- The Hypercode ANTLR playground could not be validated because the ANTLR runtime JAR is missing and automatic download failed.
- No grammar tests were executed as a result.

## Build and Test Attempts
- `make test-all` fails while invoking the ANTLR tool because `antlr-4.13.0-complete.jar` is absent; the build stops before generating lexer/parser sources.
- Attempting to fetch `antlr-4.13.0-complete.jar` via `make antlr-4.13.0-complete.jar` (which runs `curl -O https://www.antlr.org/download/antlr-4.13.0-complete.jar`) is blocked in this environment with `curl: (56) CONNECT tunnel failed, response 403`.

## Current Blockers
- Network restrictions prevent downloading the ANTLR JAR from `https://www.antlr.org/download/`.

## Suggested Next Steps
- Provide the ANTLR JAR via a vendored copy, alternative mirror, or pre-populated cache accessible in this environment.
- After obtaining the JAR, rerun `make test-all` to regenerate sources and execute the grammar test suite in `hypercode_tests/`.
