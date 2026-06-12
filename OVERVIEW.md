# Hypercode Conceptual Overview

## 1. Purpose

> **Hypercode is a formal, provenance-preserving, context-resolved
> specification layer between human-reviewed architectural intent and
> deterministic or AI-assisted code generation.**

The shortest mental model: **CSS for application structure**. A small,
stable, addressable topology (`.hc`) plus selector-based cascade sheets
(`.hcs`) resolve — under an explicit context — into a typed, hashed,
provenance-carrying graph that downstream tooling consumes.

Hypercode does not replace general-purpose languages. It is the canonical
place where the system's *structure and its contextual policies* are defined,
reviewed, and versioned — so that code, configuration, and validation can be
derived from one deterministic source.

## 2. Two Complementary Artifacts: `.hc` and `.hcs`

### 2.1. Hypercode file (`.hc`) — the structural skeleton

A purely declarative, indentation-based declaration of *what exists*:

```hypercode
Service
  Logger.console
  Database#main-db
    Connect
  APIServer
    Listen
```

Nodes carry a **type**, an optional **class** (`.console`) and an optional
**id** (`#main-db`) — the anchors every other layer addresses. The `.hc` is
deliberately a *skeleton*, simpler than YAML: structure and intent only, no
values. ([Formal grammar](EBNF/Hypercode_Syntax.md).)

### 2.2. Cascade sheet (`.hcs`) — values, contexts, contracts

Selector-based rules attach values to the structure, context blocks
specialize them, and contract blocks declare invariants:

```hcs
APIServer > Listen:
  port: 5000

@env[production]:
  APIServer > Listen:
    port: 8080

@contract:
  APIServer > Listen:
    port: int >= 1 <= 65535
```

- **Selectors** (`type`, `.class`, `'#id'`, `parent > child`) express *where*
  a rule applies; CSS-style **specificity** plus source order decides *which*
  rule wins.
- **`@dimension[value]` blocks** (e.g. `@env[production]`, `@client[acme]`)
  express *when* rules apply; the context is supplied at resolution time
  (`--ctx env=production`).
- **`@contract:` blocks** attach property schemas (type, bounds, required)
  to selectors.

## 3. The Safety Lock: Asymmetric Cascade

The rule that makes overriding defensible (normative, [RFC §9.4](RFC/Hypercode.md)):

> Values cascade. Contracts accumulate and narrow.
> A more specific selector MAY override a value.
> A more specific selector MUST NOT weaken an inherited contract.

Hypercode cascades *behavior*, never *safety*. A production override that
violates a bound is a build error (`HC2104`), not an incident. This combines
CUE-like monotonic safety with CSS-like contextual selection.

## 4. The Resolved Graph Is the Contract

Resolution is **deterministic and happens at build/generation time**:
`.hc + .hcs + context → resolved graph → hypercode.ir/v2`
([schema](Schema/hypercode-ir-v2.schema.json)). The IR carries, per property:

- the **typed value** (`8080`, not `"8080"`),
- full **provenance** — the winning rule *and* every losing rule, each with
  selector, file, line, specificity and source order,
- the **contracts** governing it,

and, per node, a **stable content hash** (Merkle over the subtree) — the
invalidation signal for incremental regeneration.

Consumers depend on the IR, never the reverse. Target-specific output
(code, Kubernetes manifests, ontology packages, …) is consumer-owned,
downstream of the resolved graph ([backends](DOCS/Backends.md)).

## 5. The Toolchain

| Command | Question it answers |
|---|---|
| `hypercode resolve` | what does the structure look like in this context? |
| `hypercode validate --ctx …` | does the cascade respect every contract here? |
| `hypercode explain <selector> [prop]` | *why* is this value what it is? (winner + losers) |
| `hypercode emit` | the IR v2 for downstream consumers |
| `hypercode diff old.ir new.ir` | which nodes changed, and which rule did it? |
| `hypercode lsp` | live diagnostics in the editor |

Every command with real outputs: [usage guide](DOCS/Usage.md).

## 6. Where Behavior Comes From

Algorithmic behavior stays in host languages. Hypercode's role is the layer
above: an LLM or a deterministic generator consumes the resolved IR and
produces code **per node**; node hashes scope regeneration to what actually
changed; the same contracts validate the generated artifacts; provenance lets
a validator state *which rule* demanded a behavior.

The unit of human review shifts from generated code to the **specification
diff** — humans approve a small, formally resolved change; machines expand it
into code and validate the expansion (*review compression*). This loop is
runnable today: [`Examples/codegen-demo/`](Examples/codegen-demo/).

Binding time is explicit: context resolves at build/generation time. Runtime
feature flags (OpenFeature, LaunchDarkly) are a different, composable layer;
an embedded runtime resolver is an optional mode, currently out of scope
([RFC §9.8](RFC/Hypercode.md)).

## 7. What Hypercode Is Not

- **Not a typed configuration language** (CUE, Dhall, Nickel) — their subject
  is configuration *data*; Hypercode's subject is an addressable *topology*
  plus rules over it.
- **Not model-driven architecture** — `.hc` is deliberately incomplete: a
  skeleton plus context policies, not a complete model.
- **Not a Markdown SDD format** (Spec Kit, Kiro, AGENTS.md) — Hypercode sits
  *underneath* such documents as the part that resolves deterministically and
  diffs semantically.
- **Not a DI container, an interface contract, or a feature-flag system** —
  it provides stable anchors those layers can target.

Full positioning, prior-art map and phrasing discipline:
[DOCS/Positioning.md](DOCS/Positioning.md) · [RFC §9](RFC/Hypercode.md).
