# Hypercode — Core vs Dialects

The reference implementation (root Swift package) defines **core `.hc`**:

```
command ::= identifier [ "." identifier ] [ "#" identifier ]
```

plus indentation-based nesting — nothing else.

Hyperprompt's `HypercodeGrammar` module is a **richer dialect** built on the same
SpecificationCore foundation, adding layers core does not have:

| Feature | Core `.hc` | Hyperprompt dialect |
|---|---|---|
| command / class / id / nesting | ✅ | ✅ |
| quoted literals | — | ✅ (`Lexical/Quotes`) |
| references | — | ✅ (`Syntactic/References`) |
| path values + security (traversal / root) | — | ✅ (`Semantic/Paths`, `Security`) |
| line classification | blank / command | blank / comment / node (`Decisions`) |

## Proposal: core vs extensions

1. **Keep core minimal** — the core grammar-core stays the small, shared base
   every consumer can rely on.
2. **Model dialect features as additive specification layers** on top of core,
   not forks of it. The Specification pattern makes composing optional layers
   (quotes, references, paths) natural.
3. **Extraction order** (workplan M6): grow core here, then refactor Hyperprompt
   onto it (HC-062) — moving genuinely-shared lexical/syntactic specs into core,
   leaving prompt-specific layers (references, path security) in Hyperprompt —
   then do the same for Ontology (HC-063).

## Open question (gates HC-062 / HC-063)

Are references / quotes / paths meant to become part of **core** Hypercode
eventually, or stay **dialect-only**? That decision sets the core surface and is
the prerequisite for the consumer refactors. Flagging for a maintainer call.
