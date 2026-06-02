# Hypercode IR schema

`hypercode-ir-v1.schema.json` is the versioned JSON Schema for the canonical
resolved-graph IR (`hypercode.ir/v1`) produced by `hypercode emit`.

It is the **cross-implementation contract**: consumers (Ontology, Hyperprompt,
…) read this shape instead of re-implementing the `.hc` / `.hcs` parser and
cascade resolver. Target-specific projections (e.g. a `DomainOntologyPackage`
YAML) are built *from* this IR, on the consumer side.

The IR is a **generated artifact** — `.hc` + `.hcs` remain the source of truth.

## Regenerate the fixture

```bash
swift run hypercode emit \
  Examples/service.hc --hcs Examples/service.hcs \
  --ctx env=production --format json > Schema/fixtures/service.production.ir.json
```
