# Dogfooding Log (HC-121)

Hypercode adopted for real artifacts from its own ecosystem. Each entry
records what was modeled, what worked, and — the actual point — what hurt.
Friction items are numbered (F1…) and feed the workplan.

## Entry 1 — Ontology `examcalc` package (2026-06-12)

**What:** the real `DomainOntologyPackage` for `examcalc` (Ontology repo,
`SPECS/ontology/packages/examcalc/`) — 13 classes, 8 relations, 4 policies,
a 7-state machine — modeled as
[`Examples/ontology-backend/examcalc.{hc,hcs}`](../Examples/ontology-backend/)
with a consumer-side adapter regenerating the YAML from IR v2. CI compares
the result semantically against a verbatim copy of the original; it matched
on the first complete run.

### What worked

- **Selector defaults are the real product.** Four kind rules
  (`.entity`/`.capability`/`.command`/`.event`) plus type-level defaults for
  `Relation` and `Policy` carry everything the YAML restates per entry. The
  per-node rules contain only what is actually specific.
- **`@stage[approved]`** turns `approvalStatus` from an edited field into a
  resolved context; `hypercode diff` shows package approval as exactly one
  affected node.
- **Contracts on a document that had none:** `card_min: int >= 0`, required
  `domain`/`range`/`text` — `validate` now gates edits that previously went
  straight to the consumer compiler.
- **The Backends.md boundary held.** Every piece of schema knowledge
  (envelope, key spelling, list encoding) fit naturally in the adapter;
  nothing leaked into core.

### Friction

- **F1 — no list values in core.** `implements`, `appliesTo`, `states`,
  `oneOf` ranges and the compatibility lists travel as comma-joined strings;
  the split convention is an undocumented contract between sheet and
  backend. Tolerable at this size, but it is the first thing a second
  consumer would re-invent differently. *Candidate: list scalars as a core
  extension or a sanctioned dialect layer (M9 discussion; conflicts with
  "core stays minimal" — needs a decision, not a default).*
- **F2 — contract types are single-typed.** The schema's
  `cardinality.max: int | "*"` is inexpressible; `card_max` ships
  unconstrained. *Candidate: union types or value-pattern constraints in the
  contract grammar.*
- **F3 — synthetic sibling ids.** Same-type siblings (the five `Transition`
  nodes) need invented ids (`#start`, `#verify`, …) purely to be
  addressable. Honest cost of the anchor model; the invented names did turn
  out useful in `explain`/diff output.
- **F4 — id-selector quoting noise.** Every per-node rule reads
  `'#Exam':` — the quotes (because bare `#` opens a comment) are the most
  common syntax error while writing the sheet.
- **F5 — flat property names.** Nested YAML keys (`metadata.id`,
  `cardinality.min`) flatten to `package_id`, `card_min`; the mapping lives
  in the backend. Correct per the layering rules, but it means the sheet and
  the target document drift vocabularies — provenance bridges it, a naming
  convention would help.

### Verdict

Parity on size for one package (201 vs 212 meaningful lines), clear wins on
defaults, lifecycle-as-context, diff, contracts and provenance. The
compression story starts at the second package, when the kind defaults and
contracts move to a shared `@import`ed baseline. Next adoption step
(remaining scope of HC-121): an `import-hypercode` step inside `ontologyc`
itself, consuming the IR the way `backend.py` does, and the same exercise
for a Hyperprompt configuration.
