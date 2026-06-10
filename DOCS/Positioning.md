# Hypercode — Positioning

The one-sentence formula:

> **Hypercode is a formal, provenance-preserving, context-resolved specification
> layer between human-reviewed architectural intent and deterministic or
> AI-assisted code generation.**

This document fixes the market positioning, the phrasing discipline around the
novelty claim, and the validation/adoption strategy. The full prior-art
analysis lives in [RFC §9](../RFC/Hypercode.md).

## The pitch, by audience

- **README hook:** *CSS for application structure* — selectors, cascade, and
  provenance over a stable program topology, with the DevTools built in
  (`explain`).
- **Engineering:** one structure, many contexts. Swap `--ctx` to get a
  different build without touching the structure, and every resolved value
  answers "why am I here?" with a selector and a source line.
- **Enterprise:** *review compression*. Humans approve a small, formally
  resolved spec diff; machines expand it into code and validate the expansion;
  every generated behavior traces back to its source selector.

## The novelty claim (phrasing discipline)

The claim is a **combination**, stated falsifiably:

> We have not found a mainstream specification or tooling stack that combines:
> a stable addressable topology, CSS-like selector cascade, deterministic
> context resolution, property-level provenance, monotonic selector contracts,
> and a resolved-IR diff for incremental AI-assisted code generation.

Never claim "nothing like this exists". Every individual ingredient has mature
prior art; the prior-art map in RFC §9.3 names it deliberately, including the
two closest relatives: **OAM/KubeVela** (structural) and **software product
lines** (academic).

## What Hypercode is not

- **Not a typed configuration language** (CUE, Dhall, Nickel, Pkl, KCL,
  Jsonnet) — they validate and generate configuration *data*; Hypercode's
  subject is an addressable *topology* plus rules over it.
- **Not model-driven architecture** — `.hc` is deliberately incomplete: a
  skeleton plus context policies, not a complete model. The term *"executable
  architecture" is deprecated* in Hypercode materials; it imports MDA/TOSCA
  expectations the design explicitly avoids.
- **Not a Markdown SDD format** (Spec Kit, Kiro, AGENTS.md) — Hypercode sits
  *underneath* such documents as the part that resolves deterministically and
  diffs semantically.
- **Not an interface contract** (OpenAPI, AsyncAPI, GraphQL) — nodes
  *reference* external contracts (`api_contract: "openapi/users.yaml"`);
  generating or owning route/payload schemas is a non-goal.
- **Not a runtime feature-flag system** (OpenFeature, LaunchDarkly) — see the
  layer answers below.

## Layer answers (for common challenges)

- **"Why not OpenFeature + CUE?"** OpenFeature decides dynamic flag values at
  runtime. CUE validates and generates configuration data. Hypercode resolves
  an addressable application topology into a provenance-preserving IR for
  explain, diff, validation, and code generation. Different layers; they
  compose.
- **"Isn't this OAM/KubeVela?"** OAM separates components from traits and
  policies for *delivery* on Kubernetes. It has no specificity cascade, no
  property-level provenance, and no codegen-oriented IR.
- **"Isn't this Spec Kit?"** Same thesis — the spec is the durable artifact,
  code is regenerated output — different layer: Markdown guides agents;
  Hypercode is the formal substrate underneath it.
- **"Cascade is what CUE banned."** See the safety lock below.

## The safety lock: asymmetric cascade

The architectural rule that makes the cascade defensible (normative, RFC
§9.4):

> Values cascade. Contracts accumulate and narrow.
> A more specific selector MAY override a value.
> A more specific selector MUST NOT weaken an inherited contract.

Hypercode cascades *behavior*, never *safety*. This combines CUE-like
monotonic safety with CSS-like contextual value selection and DevTools-like
provenance — and is the direct answer to the GCL/CUE override objection.

## Validation strategy: one deep demo

One honest comparison beats five shallow ones; every additional target invites
"you strawmanned X". The target is **Kustomize** (largest audience, most
visceral overlay-archaeology pain):

- N tenants × M environments, side by side;
- measured: duplicated structure, time to answer "why is this value here?"
  (`explain` vs. overlay archaeology), precision of affected-module
  regeneration (IR diff);
- **must include Hypercode's own failure mode** — a specificity conflict —
  and show `explain` resolving it. A demo that shows its warts is believed.

## Adoption path

1. **Dogfooding first:** Hyperprompt and Ontology consume the resolved IR
   (dialects and backends stay consumer-side, per
   [Dialects](Dialects.md) / [Backends](Backends.md)).
2. The Kustomize demo for external audiences.
3. Standalone adoption last — only after 1–2 produce evidence.

## Vocabulary

| Deprecated | Preferred |
|---|---|
| "executable architecture" | "context-resolved specification layer" |
| "a new YAML" / "config language" | "topology + rules, resolved with provenance" |
| "declarative DI" | "stable anchors for wiring, codegen, and validation" |
| "AI writes the code from the spec" (alone) | "review compression: humans approve the spec diff, machines expand and validate it" |
