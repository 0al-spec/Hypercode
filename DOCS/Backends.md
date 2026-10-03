# Hypercode — Backends & Adapters

Compilation to a concrete language or format is **not** part of Hypercode core.
`.hc` stays target-agnostic; the boundary is the resolved-graph IR.

```text
.hc + .hcs --[resolve]--> resolved graph (IR) --[adapter]--> target
                                              ├── DomainOntologyPackage YAML (Ontology)
                                              ├── .env / Terraform / ...
                                              └── <language> SDK
```

## Rules

- A **backend/adapter** consumes the IR (`hypercode.ir/v2`, or legacy v1; see
  [`Schema/`](../Schema/)) and emits one target. It lives in the
  **consumer** repo, never in Hypercode.
- Hypercode emits only the canonical, schema-agnostic IR (`hypercode emit`).
- The target is a build-time choice (a flag on the consumer's tool), not
  something encoded in `.hc`.

## Worked example: Ontology

`ontologyc` (Swift, separate repo) provides an `import-hypercode` step:

```text
*.ontology.hc + *.hcs
  -> hypercode emit                       (canonical IR)
  -> map IR -> DomainOntologyPackage YAML (ontology-specific, in ontologyc)
  -> ontologyc compile -> TypeScript SDK
```

The `--schema domain-ontology-package` knowledge stays on the Ontology side —
Hypercode never learns the ontology schema. The consumer implementation reads
`hypercode.ir/v2` JSON and maps an ontology-shaped graph to
`DomainOntologyPackage` YAML inside `ontologyc`; generic graphs still become
reviewable class drafts. Imports remain draft-only: a Hypercode context may
resolve `approval_status`, but trusted Ontology approval is a governance
decision, not an import side effect.

## Composition, generation contracts, and observations

Core supplies an addressable composition and resolved context. Consumer-owned
contracts give it platform meaning: assembly, dependency provision, input
routing, results, and lifecycle. A versioned system prompt is one possible first
form of that contract; it is guidance, not enforcement. Record the contract
version alongside source/IR revisions in generation evidence.

A richer source-code graph does not require a richer core language. A scanner
may report inheritance, calls, imports, or cycles without those becoming `.hc`
constructs. A consumer comparing desired composition with observations must
preserve extra relations, source locations, scanner capabilities, revision, and
mapping ambiguity. Projecting to a tree must not silently hide violations.
`hypercode diff` remains an IR-to-IR change report, not a code scanner.

Existing HCS contracts (§9.4 of the RFC) constrain resolved properties by
intersection and narrowing. They do not establish code-level architectural
conformance or enforce quality metrics. A future quality-policy consumer must
separately define scope, measurement provenance, thresholds, and aggregation;
measured values are observations, not authored requirements.

| Owner | Responsibility |
|---|---|
| Hypercode | Minimal structure, HCS resolution/contracts, canonical IR and provenance |
| Application / generator | Platform profile or prompt, code generation, scanners and tests |
| SpecGraph (proposed integration) | Composition/observation mapping, rule evaluation, evidence and unknown results |
| Metrics | Reusable metric definitions and pack contracts; application policies choose thresholds |
| Viewer consumer | Projection, overlays, and navigation to evidence |

The existing [codegen demo](../Examples/codegen-demo/README.md) checks node-hash
freshness and generated CONFIG values against property contracts. It is a
bounded example, not a general architecture scanner. A UML Viewer adapter should
start with an explicit composition subset; full EDN round-trip is not a core
requirement. Future consumer work may use a separate Clojure application to
exercise scanner and viewer output; no application or adapter is introduced here.

The [integration source draft](uml-viewer-specgraph-integration-source-draft.md)
records the discussion. Proposed SpecGraph contract:
[SG-RFC-0219](https://github.com/0al-spec/SpecGraph/blob/main/docs/proposals/0219_composition_observation_contract.md).
It is not an implemented integration or a change to Hypercode grammar/IR.
