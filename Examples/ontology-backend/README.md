# HC-121 — Dogfooding: a real Ontology package through the IR

The worked example of [DOCS/Backends.md](../../DOCS/Backends.md), runnable.
The **real** `examcalc` DomainOntologyPackage from the Ontology repo —
13 classes, 8 relations, 4 policies, a 7-state machine, 240 lines of
hand-written YAML — described as `examcalc.{hc,hcs}` and regenerated through
the resolved IR by a consumer-side adapter:

```
examcalc.hc + examcalc.hcs ──▶ hypercode emit (IR v2) ──▶ backend.py ──▶ DomainOntologyPackage YAML
                                                              │
                                            semantically compared in CI against
                                            expected/ — a verbatim copy of the
                                            Ontology repo's hand-written file
```

```console
$ python3 backend.py --check
generated DomainOntologyPackage is semantically identical to the Ontology repo original (240 lines of YAML)
```

All schema knowledge — envelope constants, key names, the comma-joined list
encoding — lives in [`backend.py`](backend.py), per the Backends rule:
*Hypercode never learns the ontology schema*.

## Where the cascade earns its keep

The YAML repeats per entry what the sheet states once per **kind**:

```hcs
.entity:
  extends: "sg:DomainEntity"     # covers 7 classes

.command:
  extends: "sg:Command"          # covers 4

Relation:
  card_min: 0                    # covers 5 of 8 relations;
  card_max: "*"                  # the three 1..1 pairs override

Policy:
  extends: "sg:Policy"
  enforceability: "runtime"      # covers all 4
```

And every derived value stays explainable:

```console
$ hypercode explain examcalc.hc --hcs examcalc.hcs "'#ExamSession'" extends
Node: Package#examcalc > Classes > Class.entity#ExamSession
  extends
    WINNER   .entity { value: sg:DomainEntity }
             file: examcalc.hcs  line: 8  specificity: (0,1,0)  order: 0
```

## Context and diff on a real document

`approvalStatus` is a lifecycle value, not data — so it is a context:

```console
$ hypercode emit examcalc.hc --hcs examcalc.hcs > draft.ir.json
$ hypercode emit examcalc.hc --hcs examcalc.hcs --ctx stage=approved > approved.ir.json
$ hypercode diff draft.ir.json approved.ir.json
~ Package#examcalc > Metadata
    ~ approval_status: draft → approved
          was: Metadata @ examcalc.hcs:30
          now: Metadata @ examcalc.hcs:39

1 affected node(s)
```

One affected node — approving a package invalidates exactly the artifacts
derived from its metadata, nothing else. Contracts gate edits the same way
they gate the other examples: `card_min: -1` or a missing relation `domain`
fails `hypercode validate` before the package ever reaches `ontologyc`.

## The honest part

For a *single* package the size is parity, not victory: 201 meaningful spec
lines vs 212 meaningful YAML lines. The compression argument starts at the
**second** package, when `.entity`/`.command` defaults and the contracts move
to a shared baseline imported by every package sheet (`@import`, HC-116) —
the same shape as the [Kustomize comparison](../kustomize-comparison/)'s
tenant sheets. What a single package gains today is not size: it is selector
defaults, per-context lifecycle, semantic diff, contract gating and
provenance on a document that previously had none of those.

Everything that hurt while writing this is recorded in
[DOCS/Dogfooding.md](../../DOCS/Dogfooding.md) — the friction log is the
deliverable dogfooding exists to produce.

| File | Role |
|---|---|
| `examcalc.hc` | the package topology (42 meaningful lines) |
| `examcalc.hcs` | kind defaults + per-node specifics + `@stage` + contracts |
| `backend.py` | consumer adapter: IR v2 → DomainOntologyPackage; `--check` for CI |
| `expected/domain-ontology-package.yaml` | verbatim copy of the Ontology repo original |
