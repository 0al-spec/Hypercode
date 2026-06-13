# Type-System Depth Backlog

**Status:** Planned · **Date:** 2026-06-13 · Backlog contract for RFC §10
"Type-system depth".

## The gap

IR v2 carries scalar typed values (`string`, `int`, `double`, `bool`) and the
contract layer enforces scalar type/bounds/requiredness. Dogfooding exposed the
next real pressure points:

- **F1 lists:** Ontology fields such as `implements`, `appliesTo`, `states`,
  relation `oneOf`, and compatibility lists currently travel as comma-joined
  strings.
- **F2 unions:** `cardinality.max` is semantically `int | "*"`, but contracts
  cannot express that.

Those are real gaps, but adding a full configuration-language type system would
violate the core invariant: Hypercode is an addressable topology plus resolved
properties, not a replacement for CUE/Pkl/Dhall/KCL.

## Design constraints

- Keep the core smaller than YAML: no arbitrary maps in `.hcs` v1.
- Preserve deterministic IR hashing and JSON Schema compatibility.
- Keep selector contracts monotonic: richer types must still only narrow.
- Preserve consumer ownership of target schemas. Hypercode may type a value; it
  must not learn DomainOntologyPackage, Terraform, or prompt-specific schemas.

## Candidate sequence

1. **HC-125 list scalars.** Add a minimal list literal or sanctioned list
   scalar convention, with IR v2/v3 migration rules and contract syntax such as
   `list<string>`.
2. **HC-126 union or pattern constraints.** Cover `int | "*"` either with
   explicit unions (`int | string`) or a narrower scalar pattern form for
   sentinel values. This must include monotonicity rules.
3. **HC-127 nested property naming convention.** Decide whether flattened keys
   such as `card_min` stay a consumer convention or get a core spelling
   convention for target-path provenance.

## Acceptance criteria for any type-depth change

- RFC and `EBNF/Hypercode_Syntax.md` syntax updates.
- Reader/parser tests for good and bad literals.
- Contract monotonicity tests and HC2104 value-enforcement tests.
- IR schema update and migration note.
- A dogfooding example that removes at least one F1/F2 workaround without
  making `.hcs` visibly more complex.

## Release posture

This is not a 0.6.0 blocker. The current scalar model is honest and usable; the
type-depth work should wait until at least two consumers need the same richer
shape, so the extension is common infrastructure rather than Ontology-specific
schema leakage.
