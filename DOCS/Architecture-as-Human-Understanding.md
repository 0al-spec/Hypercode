# Developer Note: Architecture as Human-Readable Understanding

> **Status:** exploratory product direction. This note describes a possible use
> of Hypercode's existing structure, context resolution, provenance, contracts,
> and IR. It does not change the `.hc` grammar or define new runtime semantics.

## The question behind better AI explanations

Andrej Karpathy has recently argued that as models take on more of the work,
people will spend more time understanding their outputs, and that purpose-built
diagrams, web pages, and other disposable artifacts can make that understanding
more effective. This suggests a prior question for software architecture:

> What durable representation should an explanation be based on, so that it
> does not have to be reconstructed from a large codebase every time?

Hypercode could serve as a compact, human-readable layer of architectural
decisions that guides agent work and gives people a stable basis for reviewing
the result. The opportunity is not simply to ask an AI to summarize code after
it has been written. It is to preserve an intentional structure throughout
design, implementation, and review, then generate different explanations from
that shared basis.

This direction builds on Hypercode's existing model: `.hc` describes structure,
`.hcs` supplies context-dependent values and policies, and resolution produces
a graph/IR with contracts and property-level provenance. The product question
is how this mechanism can help people retain control of important architectural
decisions while implementation detail grows.

## 1. Start with a map of decisions, not a summary of code

Consider a possible architecture sketch for BuildHunter. It is an example of a
design conversation, not a description of BuildHunter's current implementation:

```hc
Application#buildhunter
  Discovery#discovery
    SearchRoots#roots
    CacheCandidates#candidates
  Assessment#assessment
    Evidence#evidence
    ProtectionRules#protection
  Cleanup#cleanup
    DeletionPlan#plan
    UserApproval#approval
    TrashOperation#trash
```

The sketch makes several responsibilities available for discussion before it
specifies filesystem traversal, concurrency, concrete APIs, or UI. Are discovery,
assessment, and cleanup distinct responsibilities? Does deletion need an
explicit plan? Where should protection policy live? What exactly does the user
approve?

The example deliberately uses only `.hc`'s structural core: an identifier, an
optional class and ID, and nesting. It does not add relationships such as
`uses`, `emits`, or `consumes` to the core. Nor does nesting assert execution
order: the position of `UserApproval` in this tree does not prove that approval
must happen before `TrashOperation`. A meaningful relationship, condition, or
constraint needs semantics supplied through `.hcs`, an external contract, or a
consumer adapter. A suggestive name alone does not enforce behavior.

The goal is to keep each kind of complexity at the level that owns it, rather
than hide it. The structure gives people concise, stable subjects for
architectural discussion; context and contracts give selected properties
deterministic meaning; consumers supply domain-specific interpretation.

## 2. Treat a node as an architectural responsibility

A Hypercode node need not correspond to one class, file, or module. It can name
an architectural responsibility that remains useful to discuss as its
implementation changes. `#assessment` might be implemented by many types today,
fewer after a refactor, or different constructs in another language. The
architectural question can remain stable:

> On what basis does the system decide that a discovered directory is safe to
> clean up?

An explicit ID such as `#assessment` could give tools and people a durable
address for connecting a requirement, design decision, implementation mapping,
check, and review discussion. These connections should be explicit external
metadata or consumer-owned mappings; matching a source-code name to an
architecture ID must not silently define identity. Renaming a Swift type should
not by itself erase an architectural responsibility.

With stable identities, a reviewer can ask, “What changed under `#assessment`,
why did it change, and which checks cover it?” That is a more precise entry
point than rediscovering the architecture from filenames and prose.

## 3. Optimize the information needed for a human decision

The review-compression direction in [Positioning](Positioning.md) is central:
people review a small, resolved change in intent; tools expand and check the
implementation. The target is not fewer lines in every diff. It is less
information a reviewer must read to decide whether a particular architectural
change is acceptable.

For a change to cache discovery, a reviewer may need to know whether it changes
only discovery methods, expands the roots that can be searched, alters
eligibility rules, or creates a path around user approval. A large source diff
can implement one architectural change; a one-line change can remove an
important restriction.

A resolved specification diff can make the intended change easier to see, but a
small specification diff does not make a large implementation diff safe by
itself. The implementation must still be checked for fidelity and for
unintended changes. Review can therefore proceed in two passes:

1. Understand the declared change in intent and constraints.
2. Inspect implementation evidence for the intended behavior and for
   out-of-scope effects.

The quality measure is whether a reviewer can predict consequential changes
within the model's stated scope, not whether the model is maximally short.

## 4. One resolved basis, multiple explanations

The authored structure and its resolved machine representation have different
jobs. `.hc` remains a readable source for topology; `.hcs` supplies context;
the resolved IR is the machine-readable basis for consumer-specific views:

```text
.hc structure + .hcs context
              ↓
       resolved graph / IR
              ↓
      consumer-side adapter
              ↓
 explanation for a particular question
```

A newcomer might see responsibilities and boundaries. A PR author might see
the affected nodes and rules. A reviewer might see changed constraints and
available checks. An incident investigator might see the intended structure
beside observations from a particular build or trace. These views should refer
to the same architecture identities, IR revision, and evidence sources; only
the selection and presentation should vary by question.

Keep system context separate from presentation context. A system context such
as `env=production` may change which values resolve. The applicable contracts
remain determined by selector matches; those same contracts are checked against
the context-resolved values, so the validation result may differ by context. An
explanation preference such as “for a new contributor” should change
presentation, not resolved values. Similarly, a static hierarchy cannot justify
an execution animation. A sequence view needs an explicit behavioral model,
scenario, or observed trace; otherwise it depicts an assumption as if it were
fact.

The rendered page, diagram, or explainer can be disposable. The architecture
identities, source revision, selected system context, decision records, and
evidence behind its claims need durable references so the explanation can be
reproduced after the presentation is gone.

## 5. Show what is known and how it is known

An explanation should distinguish claims with different evidence strengths.
For a user-approval requirement, these statements are not interchangeable:

- **Declared:** the architecture or policy requires approval.
- **Resolved:** under a named system context, a rule resolves a property to a
  value; provenance identifies the winning rule and the alternatives it
  superseded.
- **Observed:** a named check passed for a specific commit, or a specific trace
  contains an approval step.
- **Inferred:** an agent believes the rule exists to prevent false-positive
  cleanup, but no linked decision record establishes that rationale.

Hypercode's property provenance supports explaining how a value was resolved.
It does not, by itself, prove that the implementation follows that value.
Likewise, one passing test establishes only what that test ran and asserted; it
does not prove that no path can bypass approval. Claims about implementation
behavior need evidence with an explicit scope, revision, and method of analysis.

Deterministic tools should report facts they can establish. An LLM can help
select and explain those facts, but its inferences should remain labelled as
inferences. High-value facts such as resolved values, affected IDs, and check
results should be rendered from structured data where possible instead of
re-extracted from free-form model prose.

## 6. Make change explanation the first product experiment

A useful first question is narrower than “explain the whole architecture”:

> Explain what this PR changes about the product's architecture, and show where
> each conclusion is supported.

For example, an inspector for `#cleanup` might report that the execution path
changed, the approval requirement resolved unchanged, a cancellation check
passed, and the new execution path has no linked check for the approval
constraint. The last finding reports missing evidence; it does not silently
turn absence of evidence into proof of either safety or a violation.

Keep three things distinct:

```text
Architectural intent and constraints → expected design
Source, checks, and traces          → implementation evidence
Explicit mappings and analysis      → correspondence and gaps
```

The expected design and observed implementation are not necessarily graphs of
the same shape: many code elements can implement one architectural
responsibility. Connecting them requires explicit mappings, a stated analysis
scope, and pinned code and context revisions. Updating the expected design to
match an agent's implementation must be a separate reviewed proposal; otherwise
the agent could rewrite its target and report that it met it. Implementation,
intent changes, and conformance evidence are separate artifacts.

## 7. Keep the core small and evaluate the hypothesis

The general idea of a shared architecture model with multiple views is
established prior art. The [C4 model](https://c4model.com/) defines hierarchical
abstractions and diagram types; [Structurizr DSL](https://docs.structurizr.com/dsl)
provides a textual way to define a C4-based architecture model. Hypercode's
potential distinction is the combination it already pursues: a compact
addressable topology, context resolution, property-level provenance,
accumulating contracts, resolved-IR diffing, and a path to agent-assisted
generation and review. That combination needs practical evidence before it
should be presented as a product advantage.

Three boundaries protect the idea from growing into a second source language:

- Keep `.hc` intentionally incomplete; do not duplicate implementation logic
  in an architectural model.
- Do not treat node names as formal semantics. Domain meaning comes from
  documented vocabularies, contracts, and consumer adapters.
- Keep source and diff views useful without a visualizer. Interactive pages and
  diagrams can improve navigation, but they should not be the only way to read
  the architecture.

Test the idea with one project and a small architectural slice. A first
prototype can be read-only: load `.hc`, resolve `.hcs`, inspect nodes, link
implementation and checks, and show changes. Code generation is not required
to test whether the understanding layer helps.

Compare three review conditions: an ordinary PR with existing documentation, a
free-form LLM explanation, and an explanation grounded in Hypercode plus
explicit implementation evidence. Give reviewers the same questions about
responsibilities, changed rules, and possible approval bypasses. Include both
valid changes and known violations. Measure answer accuracy, review time,
missed violations, unsupported confidence, and the cost of keeping the
architecture model current. Faster answers with more missed violations would
be a usability gain without an understanding gain. Better answers with
traceable support would be evidence for the product hypothesis.

## Summary

Hypercode can preserve architectural intent in a compact, addressable form.
Agents may expand that intent into implementation detail; people should retain
a way to understand consequential changes, discuss them, and inspect the basis
for claims about their results. Text, diagrams, interactive pages, and videos
then become different views over shared architectural objects and evidence,
not independent model-generated stories.

The product hypothesis is not merely that AI should explain its code more
fluently. It is that a system can preserve what people need to understand and
control even when the implementation becomes too large to reread for every
review.

## Inspiration

- Andrej Karpathy, [post on diagrams, web pages, and explainer videos as ways to
  understand model outputs](https://x.com/karpathy/status/2105819303471976479).
- Hypercode's existing [positioning](Positioning.md) and
  [architecture boundaries](Architecture.md).
