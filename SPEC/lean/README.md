# Hypercode cascade oracle (Lean 4)

A machine-checked executable model of the cascade resolver (the Swift
implementation under `swift/Sources/Hypercode/HCS/`).

`HypercodeOracle.lean` checks, at `lake build` time:

- **Oracle agreement** — the RFC §5 service example resolves to exactly the
  values the Swift implementation produces, for both the development and
  `env=production` contexts (8 `native_decide` checks: specificity override
  `#main-db` ≻ `Database`, source-order override, non-overridden inheritance, …).
- **Order facts** (kernel-checked, `decide`) — `#id` ≻ `.class` ≻ `type`, child
  selectors sum their specificity, `#id` ≻ `Type > Type`.
- **Totality** — `cascade_total`: a non-empty candidate list always resolves.

Lean enforces totality of every definition, so the model cannot be ill-defined.

## Build

```bash
cd SPEC/lean
lake build      # needs the Lean toolchain; lean-toolchain pins v4.30.0
```

## Toolchain

Installed via `elan` into `~/.elan` (no shell-profile changes). Remove with
`rm -rf ~/.elan`.

## Scope

This is the "sweet spot" oracle: it pins determinism's tricky part (the
precedence order) and certifies agreement with the reference implementation via
the shared fixtures. A full order-independence / generic `LinearOrder` proof is
future work — layered on now that the rules are live.
