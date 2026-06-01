# Hypercode Resolution Semantics

**Status:** Draft

**Version:** 0.1

**Date:** June 2, 2026

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
object under `swift/Sources/Hypercode/HCS/`. This document narrates those specs
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

## 7. Conformance

The reference fixtures are [`swift/Examples/service.hc`](../swift/Examples/service.hc)
and [`service.hcs`](../swift/Examples/service.hcs), resolved in
`swift/Tests/HypercodeTests/CascadeResolverTests.swift` for both the development
context (`{}`) and `env=production`, including specificity override
(`#main-db` ≻ `Database`), source-order override, non-overridden inheritance,
and provenance. Any conforming resolver must reproduce those results, e.g.:

```bash
hypercode resolve swift/Examples/service.hc --hcs swift/Examples/service.hcs --ctx env=production
```

## 8. Deferred

- **Origin / importance.** RFC §4.2.3 lists origin/importance above specificity
  in the precedence order. There is no syntax for it yet (no `!important`,
  no override-file origin), so the current precedence key is
  `(specificity, source-order)`. When syntax is introduced, it becomes the
  most-significant component of `precedence`.
- **Typed scalars.** Property values are currently raw strings (quotes stripped).
  Typed scalars (bool/int/…) arrive with real YAML input, if ever needed.
