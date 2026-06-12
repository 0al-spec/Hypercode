# HC-120 — One app, two source trees: Kustomize vs Hypercode

The same product — a `checkout` web service shipped to **3 tenants × 3
environments = 9 build targets** — maintained twice:

- [`kustomize/`](kustomize/): an *idiomatic* Kustomize tree — shared `base/`,
  reusable tenant and environment [components], 9 leaf overlays. Not a straw
  man: components are exactly the tool Kustomize offers against tenant × env
  combinatorics, and every overlay builds with `kubectl kustomize`.
- [`hypercode/`](hypercode/): one `.hc` topology, a `base.hcs` baseline with
  `@env[…]` blocks and contracts, and one sheet per tenant via `@import`
  (HC-116). 9 targets = 3 sheets × 3 `--ctx` values.

The comparison is about **the layer humans edit and review**. Rendering K8s
manifests from the resolved IR is a consumer backend
([DOCS/Backends.md](../../DOCS/Backends.md)) and out of scope here.

[components]: https://kubectl.docs.kubernetes.io/guides/config_management/components/

## Metrics

`python3 metrics.py --check` (runs in CI; numbers are computed, not claimed):

```console
3 tenants x 3 environments = 9 build targets

                           kustomize   hypercode
------------------------------------------------
files                             28           5
meaningful lines                 278          57
duplicated lines                 240          17
duplication share                86%         30%

all 9 hypercode targets validate (contracts enforced per context)
```

A line counts as *duplicated structure* when the same normalized line occurs
in more than one file of the same tree. The Kustomize number is dominated by
patch envelopes — every patch restates `apiVersion`/`kind`/`metadata`/the
container path before it can change one value. That envelope is not noise:
it is text a reviewer must read to know *what* the patch touches.

The structural difference behind the numbers: tenant × env knobs (Acme's
production DB endpoint and pool size) have no home in either a tenant
component or an env component — they leak into **leaf overlays**, one
directory per combination, which is where N × M trees rot. In Hypercode the
same knob is one block in the tenant's sheet, scoped by `@env[prod]`.

## Scenario 1 — "Why is the pool size 80 in Acme prod?"

**Kustomize.** The value is assembled from three files; you find them by
search, then mentally replay patch order (base → components → overlay
patches):

```console
$ grep -rln "DB_POOL_SIZE" kustomize/
kustomize/overlays/acme-prod/patch-db.yaml      # 80  ← wins (overlay patch, last)
kustomize/components/envs/prod/patch-env.yaml   # 50
kustomize/base/deployment.yaml                  # 10
```

Nothing in the tree *states* which one wins — you must know the merge
semantics, and `kubectl kustomize` outputs the final YAML without the why.

**Hypercode.** The cascade is a first-class object; ask it:

```console
$ hypercode explain hypercode/checkout.hc --hcs hypercode/tenants/acme.hcs \
    --ctx env=prod "'#main-db'" pool_size
Node: Checkout > Database#main-db
  pool_size
    WINNER   #main-db { value: 80 }
             file: hypercode/tenants/acme.hcs  line: 8  specificity: (1,0,0)  order: 8
    ────────────────────
    losing   #main-db { value: 50 }
             file: hypercode/base.hcs  line: 29  specificity: (1,0,0)  order: 6
    losing   #main-db { value: 10 }
             file: hypercode/base.hcs  line: 12  specificity: (1,0,0)  order: 2
```

One command, every contender, file:line each, and the tie-break rule
(equal specificity → later source order → the tenant sheet) is visible
instead of implied.

## Scenario 2 — One-line change: which targets are affected?

Bump Acme's production pool from 80 to 90.

**Kustomize**: the change lives in `overlays/acme-prod/`, but proving the
blast radius means rebuilding all 9 targets and diffing rendered YAML —
`kubectl kustomize` has no semantic diff.

**Hypercode**: emit and diff the resolved documents:

```console
$ hypercode diff old.ir.json new.ir.json
~ Checkout > Database#main-db
    ~ pool_size: 80 → 90
          was: #main-db @ hypercode/tenants/acme.hcs:8
          now: #main-db @ hypercode/tenants/acme.hcs:8

1 affected node(s)
```

One affected node, named, with the rule that did it — the invalidation feed
a regeneration pipeline consumes directly
([codegen demo](../codegen-demo/)).

## Scenario 3 — Hypercode's own failure mode, honestly

The cascade has a sharp edge: **specificity beats source order**. A tenant
author tries to override the DB host with a *type* selector:

```hcs
@import "../base.hcs"

@env[prod]:
  Database:                      # ← (0,0,1) — type selector
    host: db.initech.internal
```

It silently loses — the baseline's `'#main-db'` rule is an *id* selector,
`(1,0,0)`, and ids outrank source order. Production resolves to
`host: localhost`. In CSS this class of bug is debugged with devtools; in a
YAML overlay tree, with despair. Here, the same one command pinpoints it:

```console
$ hypercode explain hypercode/checkout.hc --hcs hypercode/tenants/initech-broken.hcs \
    --ctx env=prod "Database" host
Node: Checkout > Database#main-db
  host
    WINNER   #main-db { value: localhost }
             file: hypercode/base.hcs  line: 12  specificity: (1,0,0)  order: 2
    ────────────────────
    losing   Database { value: db.initech.internal }
             file: hypercode/tenants/initech-broken.hcs  line: 7  specificity: (0,0,1)  order: 8
```

The loser is listed with the reason it lost — fix is to target `'#main-db'`,
as [`tenants/acme.hcs`](hypercode/tenants/acme.hcs) does. The honest summary:
Hypercode does not remove override complexity; it makes every override
**explainable** and gates it with contracts (`pool_size: 99999` in any tenant
sheet fails `validate` with HC2104 before anything ships — try it).

## Reproduce

```console
$ python3 metrics.py --check          # metrics + validate all 9 targets
$ kubectl kustomize kustomize/overlays/acme-prod   # any overlay builds
```

| File | Role |
|---|---|
| `kustomize/base/` | shared manifests (Deployment, Service, ConfigMap) |
| `kustomize/components/tenants/*` | reusable per-tenant patches (branding) |
| `kustomize/components/envs/*` | reusable per-env patches (replicas, logging, pool) |
| `kustomize/overlays/<tenant>-<env>/` | 9 leaf targets; tenant × env knobs leak here |
| `hypercode/checkout.hc` | the topology (5 lines, never changes per target) |
| `hypercode/base.hcs` | defaults + `@env[…]` blocks + contracts |
| `hypercode/tenants/*.hcs` | one sheet per tenant, `@import "../base.hcs"` |
| `metrics.py` | computes the table above; `--check` validates all targets |
