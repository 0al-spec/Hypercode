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

- A **backend/adapter** consumes the IR (`hypercode.ir/v1`, see
  [`swift/Schema/`](../swift/Schema/)) and emits one target. It lives in the
  **consumer** repo, never in Hypercode.
- Hypercode emits only the canonical, schema-agnostic IR (`hypercode emit`).
- The target is a build-time choice (a flag on the consumer's tool), not
  something encoded in `.hc`.

## Worked example: Ontology

`ontologyc` (Swift, separate repo) would add an `import-hypercode` step:

```text
*.ontology.hc + *.hcs
  -> hypercode emit                       (canonical IR)
  -> map IR -> DomainOntologyPackage YAML (ontology-specific, in ontologyc)
  -> ontologyc compile -> TypeScript SDK
```

The `--schema domain-ontology-package` knowledge stays on the Ontology side —
Hypercode never learns the ontology schema. Since `ontologyc` and the Hypercode
reference tooling are both Swift, the consumer can either link the `Hypercode`
library or shell out to the `hypercode` CLI and read the IR file.
