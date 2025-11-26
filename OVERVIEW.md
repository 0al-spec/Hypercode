
## Hypercode Conceptual Overview ("Constitution Draft", v3)

### 1. Purpose

Hypercode is an **executable architecture language**.

It is designed to describe **how a system is structured at the level of architecture**, and how concrete behavior emerges from that structure and its contextual specialization:

- which elements (agents, services, commands, tasks) exist,
- how they are related and composed,
- which stages and alternative paths are structurally defined,
- how this structure is specialized across environments, tenants, and feature sets.

Its goal is **not** to replace general-purpose languages, but to become the **canonical place where the system's architectural structure is defined**, so that behavior emerges from the combination of that structure and contextual rules.

---

### 2. Two Complementary Artifacts: `.hc` and `.hcs`

Hypercode consists of two tightly related artifacts.

#### 2.1. Hypercode file (`.hc`) – architectural skeleton

A `.hc` file is a **purely declarative structural declaration** of the system:

- Declares **structural elements** of the system (nodes, agents, commands, pipelines, states).
- Declares **structural topology and element relationships**:
  - which elements exist and their hierarchical containment,
  - which stages form a sequence,
  - which named alternatives or fallback slots are declared,
  - what structural connections exist between elements.

In the ideal model, **host components are shaped by the Hypercode architecture**, not the other way around: implementations are designed as projections of Hypercode elements and roles, following an "architecture-first" style inspired by ideas like Elegant Objects and EOlang.

This is already **meaningful structure** – it defines the **architectural shape** of the system, not algorithmic behavior.

#### 2.2. Hypercode Cascade Sheet (`.hcs`) – contextual specialization & policies

A `.hcs` file describes how the declared structure behaves under different contexts by applying **cascade- and context-aware rules** to elements from `.hc`:

- Contains **selector-based rules** that apply to elements declared in `.hc`.
- Modulates **how the architecture behaves in specific contexts**:
  - enables or disables certain elements or paths,
  - switches implementations or routes,
  - adjusts limits, timeouts, retries, strategies,
  - applies security, logging, or resource policies.
- Uses **cascade semantics**: more specific rules override general ones in a deterministic way.
- Uses **context-aware directives** (`@env`, `@profile`, `@feature`, etc.) to express how architecture changes across environments and scenarios.

Together, `.hc` and `.hcs` describe an **executable architectural program**:
`.hc` defines *what exists and how it is arranged*, `.hcs` defines *how that arrangement behaves in each context*.

---

### 3. Division of Responsibilities

Hypercode deliberately **separates levels of concern**.

#### Architectural topology & orchestration structure – in Hypercode

Hypercode expresses:

- which components participate in a scenario,
- in which sequence they are declared,
- which alternative paths are structurally defined,
- which architectural roles and connections exist between components,
- which policies and strategies are associated with particular structural elements (via `.hcs`).

#### Algorithmic & low-level behavior – in host languages

Host languages and runtimes remain responsible for:

- how a video is encoded or transcoded,
- how a database query is built and optimized,
- how a request is validated against a schema,
- how cryptographic primitives and low-level protocols are implemented.

Hypercode is the **source of truth for architectural structure and orchestration structure**.
Host languages are the source of truth for **how each atomic step works internally**.

Behavior emerges from **interpreting the declared structure (.hc) under the contextual and cascading rules (.hcs)**.

---

### 4. Execution Model

Hypercode is not "just configuration".

There is a **Hypercode runtime** (or several runtimes in different ecosystems) that:

- loads `.hc` and `.hcs`,
- builds an **architectural execution graph** from the declared structure,
- applies cascade and context resolution to that graph,
- interprets the declared structure and drives execution according to the resolved cascade rules.

In addition to interpreted/executed-at-runtime scenarios, **Hypercode code can also be transformed ahead of time into host-language code**:

- a compiler or generator can translate `.hc + .hcs` into Swift / Java / TypeScript / other code that embeds the architectural structure and its contextual behavior,
- the resulting code is then compiled into a regular program or library,
- Hypercode in this mode becomes a **primary architectural source**, from which host code is derived.

Important nuances:

- Hypercode **does not directly construct objects** or manage memory; it **tells the runtime or generated host code**:
  - which roles and elements are declared,
  - how they are structurally connected,
  - which context rules from `.hcs` govern their activation.

- The runtime or generated code maps Hypercode elements to **concrete objects, services, processes, or containers** in a given platform:
  - Swift objects, Java services, microservices, actors, etc.

So, **Hypercode is executed through a runtime or via generated code**, but the **program being executed at the architectural level** is the combination of `.hc` (structure) and `.hcs` (contextual cascade).

---

### 5. Cascade and Context as First-Class Semantics

A key differentiator of Hypercode is that **cascade and context are built into the language model**, not bolted on via tooling conventions.

- **Selectors** (by type, ID, tags, hierarchy, roles, etc.) express *where* a rule applies in the structural graph.
- **Cascade** expresses *how multiple rules combine*, with deterministic resolution (specificity, precedence, ordering).
- **Context directives** (`@env`, `@profile`, `@tenant`, `@feature`, etc.) express *when* a rule applies.

This allows:

- expressing **multi-environment, multi-tenant, feature-flagged architecture** declaratively,
- moving scattered `if (env == "prod")` and feature-flag checks from host code into a **central, inspectable architectural program**,
- reasoning about behavior changes across contexts at the level of a single structural and rule-based model.

---

### 6. Relationship to Other Tools and Languages

Hypercode is intentionally **orthogonal** to many existing tools:

- It is **not just a DI container**: DI focuses on object graphs and injection; Hypercode focuses on **architectural structure and the policies that govern how that structure is used**.
- It is **not a plain config format**: configs store parameters; Hypercode defines the **architectural topology** of the system and how it behaves under different contexts.
- It is **not just another DSL**:
  - It is a **system-level DSL** for executable architecture,
  - **language-agnostic** by design, meant to sit above general-purpose languages,
  - with **cascade and context** as first-class constructs.

Hypercode is the place where the system's **architectural structure** is written, read, reviewed, versioned, and reasoned about —
with **behavior emerging from the combination of declared structure (`.hc`) and contextual rules (`.hcs`) interpreted by a runtime or generated into host code**.
