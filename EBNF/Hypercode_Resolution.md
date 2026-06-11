# Hypercode Resolution Semantics

**Status:** Draft

**Version:** 0.2

**Date:** June 11, 2026

**Author:** Egor Merkushev

**Licence:** MIT

## Overview

This document defines how a Hypercode structure (`.hc`) and a Hypercode Cascade
Sheet (`.hcs`) resolve, under an execution context, into a **resolved graph** —
the same tree of commands, each carrying the properties chosen by the cascade,
every value tagged with its provenance.

It is the semantic companion to the [syntax specification](Hypercode_Syntax.md)
(which defines well-formed `.hc`) and refines §4.2 of the
[RFC](../RFC/Hypercode.md).

The rules below are **executable**, not merely prose: in the reference Swift
implementation each is a SpecificationCore `Specification` / `DecisionSpec`
object under `Sources/Hypercode/HCS/`. This document narrates those specs
so other implementations can reproduce them.

## 1. Model

- **Node** — a command from the `.hc` tree: `type`, optional `class`, optional
  `id`, and ordered `children`. A node is always evaluated together with its
  ancestor path (root → parent).
- **Rule** — from `.hcs`: a `selector`, a map of `key → value` properties, an
  optional context guard `@dimension[value]`, and a 0-based source `order`.
- **Context** — a map of `dimension → value` bindings (e.g. `env → production`,
  `client → acme`) supplied at resolution time.

## 2. Selectors and matching

A selector matches a node *in context* (the child combinator needs the parent):

```text
match(type T,     n) ⇔ n.type = T
match(.class C,   n) ⇔ n.class = C
match(#id I,      n) ⇔ n.id = I
match(A > B,      n) ⇔ match(B, n) ∧ match(A, parent(n))      -- direct child only
```

(`TypeSelectorSpec`, `ClassSelectorSpec`, `IdSelectorSpec`, `ChildSelectorSpec`.)

## 3. Specificity

As in CSS, a selector's specificity is the triple `(ids, classes, types)`,
compared lexicographically; child selectors sum their parts:

```text
spec(type)   = (0, 0, 1)
spec(.class) = (0, 1, 0)
spec(#id)    = (1, 0, 0)
spec(A > B)  = spec(A) + spec(B)        -- componentwise
```

So `#id` ≻ `.class` ≻ `type`.

## 4. Context activation

```text
active(rule, ctx) ⇔ rule.guard = ∅  ∨  ctx[rule.guard.dimension] = rule.guard.value
```

A guardless (global) rule is always active. White-label / environment switching
is exactly choosing a different `ctx` — the `.hc` never changes.

## 5. Cascade

For a node `n` and property key `k`, gather the contributions of every active,
matching rule that sets `k`, and take the one with the greatest precedence:

```text
precedence(rule) = (spec(rule.selector), rule.order)      -- lexicographic

D(n, k) = { (rule.properties[k], precedence(rule), provenance(rule))
            | active(rule, ctx) ∧ match(rule.selector, n) ∧ k ∈ rule.properties }

value(n, k)      = the value of  max  D(n, k)
provenance(n, k) = (winning selector, winning source line)
```

Because `order` is unique per rule, `max` is unambiguous: higher specificity
wins, and equal specificity is broken by later source order. (`PropertyCascade`
is the `DecisionSpec` that performs this choice.)

## 6. Resolution

```text
ctx ⊢ n ⇓ ⟨ n.type, n.class, n.id,
            properties: { k ↦ (value(n,k), provenance(n,k)) | k ∈ keys(D(n, ·)) },
            children:   [ ctx ⊢ c ⇓ … for c in children(n) ] ⟩
```

The whole document resolves by applying this to each top-level node.

## 7. Contracts (HC-111)

A `@contract:` block (syntax: [Hypercode_Syntax.md §6.3](Hypercode_Syntax.md))
attaches property constraints to selectors. Values cascade (last sufficiently
specific writer wins); contracts **accumulate** — every applicable contract
governs the node simultaneously.

### 7.1 Effective contract — intersection

For a node `n` and property key `k`, the effective contract is the
**intersection** of all contracts whose selector matches `n` and that
constrain `k`:

```text
applicable(n, k) = { c ∈ contracts | match(c.selector, n) ∧ k ∈ c.properties }

effective(n, k).type     = the common type of all applicable (must agree)
effective(n, k).min      = max over declared lower bounds
effective(n, k).max      = min over declared upper bounds
effective(n, k).required = true if any applicable contract requires k
```

An **omitted bound is not a statement** — it inherits through the
intersection. A more specific contract that re-declares `k` without `min`
keeps the inherited lower bound; it does not lift it.

### 7.2 Monotonicity validation

Specificity relates two contracts only when they can govern the same node —
exactly as in the CSS cascade. The validator therefore checks a pair of
contracts only if **at least one node in the document matches both
selectors**. For such a pair where `spec(A) < spec(B)`:

| Violation | Code | Description |
|-----------|------|-------------|
| Type changed | HC2101 | `B` declares a different type than `A` for the same key |
| Interval widened | HC2102 | `B` lowers a declared `min` or raises a declared `max` of `A` |
| Required → optional | HC2103 | `B` marks `[?]` a key that `A` requires |

At **equal specificity** both contracts apply with equal force; a type
conflict makes the intersection unsatisfiable and is reported as HC2101.
Bounds at equal specificity simply intersect and are not a conflict.

All three are `error`-severity diagnostics; `hypercode validate` exits
non-zero.

### 7.3 Value validation (planned)

Checking the resolved values themselves against the effective contract
(type conformance, bounds, required presence) is diagnostic **HC2104**,
scheduled as PR-5 in [DOCS/Workplan.md](../DOCS/Workplan.md).

### 7.4 IR

IR v2 echoes the applicable contracts per property, sorted by ascending
specificity (declaration order as tie-breaker), so a consumer can re-derive
the effective contract without re-parsing the sheet.

## 8. Conformance

The reference fixtures are [`Examples/service.hc`](../Examples/service.hc)
and [`service.hcs`](../Examples/service.hcs), resolved in
`Tests/HypercodeTests/CascadeResolverTests.swift` for both the development
context (`{}`) and `env=production`, including specificity override
(`#main-db` ≻ `Database`), source-order override, non-overridden inheritance,
and provenance. Any conforming resolver must reproduce those results, e.g.:

```bash
hypercode resolve Examples/service.hc --hcs Examples/service.hcs --ctx env=production
```

## 9. Deferred

- **Origin / importance.** RFC §4.2.3 lists origin/importance above specificity
  in the precedence order. There is no syntax for it yet (no `!important`,
  no override-file origin), so the current precedence key is
  `(specificity, source-order)`. When syntax is introduced, it becomes the
  most-significant component of `precedence`.
- **Contract value validation.** §7.3 — HC2104, planned as PR-5.

*(Typed scalars, previously deferred, landed with IR v2: bare scalars are
type-inferred at parse time, with the source lexeme preserved for v1
round-tripping.)*
