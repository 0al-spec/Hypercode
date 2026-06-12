# Runtime Resolver Boundary (HC-114)

**Status:** Decided · **Date:** 2026-06-12 · Decision record for workplan HC-114
(closes RFC §10 "Performance" / the JIT-vs-AOT question).

## The question

Where does context binding happen?

1. **Build/generation time** (the current mode): `--ctx` is supplied when
   resolving; the output is a static resolved graph per context, consumed by
   generators, validators and `diff`.
2. **Embedded runtime resolver**: an application links the resolver and
   supplies per-request context (tenant, user, cohort), getting resolved
   values live from a single deployment.

RFC §9.8 had noted mode 2 as "optional, currently out of scope". This record
makes the boundary a decision, not a deferral.

## Decision

**Build/generation-time resolution is the only supported mode of the
reference implementation.** The embedded runtime resolver is **out of
scope** — excluded from the core's contract, with explicit revisit conditions
below. Consequently **HC-115** (an OpenFeature bridge for the runtime mode)
is parked.

## Rationale

1. **The product is the artifact, not the answer.** Everything that makes
   Hypercode worth using — review compression, per-node SHA-256 hashes,
   `hypercode diff` as an invalidation feed, HC2104 gating, generated-artifact
   conformance — assumes a *finished, reviewable* resolved graph. A
   per-request resolution has no stable artifact: nothing to hash, nothing to
   diff, nothing to review or attest.
2. **Provenance semantics.** At build time, provenance points at a line a
   human can review *before* anything ships. At runtime, "which rule won"
   becomes telemetry — an observability problem with its own capture,
   sampling and retention questions, foreign to the core.
3. **The validation story depends on enumerable contexts.**
   `validate --ctx …` runs once per context in CI, which works because
   build-time contexts are finitely enumerable. Per-request context spaces
   (user IDs, cohorts) are unbounded; admitting them would silently void the
   "every shipped context was checked" guarantee the contract layer provides.
4. **The runtime niche is occupied — deliberately.** OpenFeature and
   LaunchDarkly decide dynamic values per request well. Hypercode's role
   ([Positioning](Positioning.md)) is to provide the stable anchors
   (`type`/`.class`/`#id`) such systems target. A bridge would blur exactly
   the layer boundary the positioning depends on.
5. **The library stays embeddable as a fact, not as a contract.** `Resolver`
   is a pure function of `(sheet, context)`; a consumer *can* call it
   in-process today. The decision is that core makes **no runtime API
   commitments**: no caching, no sheet hot-reload, no per-request provenance
   sink, no latency guarantees. Embedding it means accepting build-time
   semantics evaluated late, with none of the runtime conveniences.

## Binding consequences for design

- Resolution remains a **pure function**. No public API may require an
  execution environment (clock, network, environment variables) at resolve
  time.
- Diagnostics, IR, hashes and `diff` stay defined over the resolved artifact.
- Interpolation placeholders that appear in sheets (e.g. the `"${DB_HOST}"`
  in RFC §4.2.2) pass through resolution as opaque strings; binding them is
  the **consumer's** generation/deploy concern, not resolver semantics.
- HC-115 (OpenFeature bridge) is parked: it only makes sense in the runtime
  mode. Runtime flags compose with Hypercode by targeting resolved anchors,
  not by flowing through the resolver.

## Revisit when

All three together, not any one alone:

1. A consumer demonstrates a deployment whose context space genuinely cannot
   be pre-resolved (true per-request combinatorics, not "many tenants" —
   N tenants × M environments enumerate fine);
2. a provenance/attestation design exists for runtime answers (what replaces
   the reviewable artifact);
3. the runtime API is drafted as a **separate package** so the core's purity
   and guarantees are untouched.

## Pointers

[RFC §9.3, §9.8](../RFC/Hypercode.md) · [Positioning — layer answers](Positioning.md)
· [OVERVIEW §6](../OVERVIEW.md)
