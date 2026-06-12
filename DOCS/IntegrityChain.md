# Integrity Chain Backlog (HC-122)

**Status:** Planned · **Date:** 2026-06-13 · Backlog contract for RFC §10
"Integrity chain".

## The gap

Hypercode now has stable source inputs, IR v2 document/node hashes, generator
examples, and contract validation. What it still lacks is an end-to-end
evidence envelope that binds those pieces into a reviewable supply-chain
record:

```text
.hc/.hcs sources
  -> resolved IR hash
  -> generator identity/version
  -> generated artifact hashes
  -> validator report
  -> optional signature / provenance envelope
```

Without that record, `hypercode diff` can explain *what* changed and generator
checks can prove freshness, but governance cannot yet answer "which generator
produced this artifact from which reviewed graph?"

## Planned contract

HC-122 should introduce a machine-readable `hypercode.attestation/v1` JSON
artifact. The first version should be unsigned by default but structurally ready
for signing.

Required fields:

- `schema`: literal `hypercode.attestation/v1`;
- `subject`: package/repository identity and source ref when available;
- `sources`: ordered `.hc`/`.hcs` inputs with path and SHA-256;
- `resolvedIR`: `version`, `documentHash`, optional file path, and SHA-256 of
  the emitted IR bytes;
- `generator`: name, version, command, and policy boundary;
- `artifacts`: generated files with path, SHA-256, and source node hash when
  node-scoped;
- `validation`: command, exit status, and validator report hash;
- `signature`: optional envelope metadata, not required for v1 conformance.

## Non-goals for v1

- No key management, PKI, DID, or transparency log in core.
- No network calls.
- No claim that generated code is correct beyond the recorded validator result.
- No replacement for SLSA provenance; use SLSA terms where they fit, but keep
  the Hypercode artifact small and local first.

## Acceptance criteria

- JSON Schema under `Schema/`.
- One CLI command or checked helper that emits the envelope for
  `Examples/codegen-demo/`.
- CI validates the envelope schema and verifies all recorded file hashes.
- RFC §8/§10 links to this artifact and states exactly which trust question it
  answers.

## Release posture

This is not a 0.6.0 blocker. It becomes release-critical only when a downstream
consumer treats generated artifacts as governance evidence rather than local
build outputs.
