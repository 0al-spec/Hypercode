# Hypercode: A Declarative Paradigm for Context-Aware Programming

**Status:** Draft

**Version:** 0.2

**Date:** June 11, 2026

**Author:** Egor Merkushev

**Licence:** Creative Commons Attribution 4.0 International License (CC BY 4.0)

## Status of this Document

This document is a **draft specification** for the Hypercode programming paradigm. It is intended to introduce the core concepts, syntax, and execution model of Hypercode and its companion format, Hypercode Cascade Sheets (HCS). The purpose of this draft is to facilitate discussion and gather feedback from the broader developer, systems, and programming language communities.

This is **not yet a finalized standard**, and details in syntax, behavior, or terminology are subject to change. Implementers are advised to treat this version as **experimental** and to expect updates as the model evolves based on practical feedback and further validation.

Feedback and contributions are welcome via the [project’s GitHub repository](https://github.com/0al-spec/hypercode) or issue tracker.

This document is released under the Creative Commons Attribution 4.0 International License (CC BY 4.0) and follows open specification principles, similar in spirit to community-driven RFCs.

## 1. Abstract

This document proposes **Hypercode**, a declarative programming paradigm designed to radically separate a program's logical structure from its contextual configuration. Hypercode introduces a model where the primary source code defines the abstract flow of execution, while external, cascading **Hypercode Cascade Sheets (HCS)** provide the concrete implementations, data, and behaviors. Drawing inspiration from the relationship between HTML and CSS, Hypercode utilizes a powerful selector-based mechanism, including context-aware **Rules** (`@rules`), to dynamically configure the program's behavior based on its execution environment (e.g., development, production, testing), feature flags, or other external states.

## 2. Motivation

Modern software systems suffer from a high degree of configuration complexity. Business logic is often intertwined with environment-specific checks (`if (env === 'production')`), boilerplate for dependency injection, and scattered configuration values. This increases cognitive load, complicates maintenance, and reduces the readability of the core logic.

Hypercode aims to solve this by:

1. **Maximizing Separation of Concerns:** Isolating the *what* (the logical structure) from the *how* (the concrete implementation and data).
2. **Reducing Boilerplate:** Eliminating conditional environment checks and manual dependency wiring from the application logic.
3. **Improving Readability:** Presenting the program's core logic as a clean, hierarchical structure, free from implementation details.
4. **Enabling Dynamic Context-Awareness:** Allowing the program's behavior to be radically altered by external configuration files without modifying the core logic.

## 3. Core Concepts

### 3.1 Paradigm

The Hypercode paradigm is built on three main components:

*  **Hypercode (`.hc` file):** A file describing the application's logical structure using simple, indentation-based hierarchy. It contains abstract commands or entities. It is analogous to an HTML document's structure. See [Hypercode Syntax Specification](../EBNF/Hypercode_Syntax.md) for the formal grammar of `.hc` files.

*  **Hypercode Cascade Sheet (`.hcs` file):** A YAML-like file that defines how to interpret and configure the commands in the Hypercode file. It uses selectors to target commands and apply configurations. It is analogous to a CSS stylesheet.

*  **Runtime Environment:** An engine that parses both the `.hc` and `.hcs` files, resolves the configurations by applying the HCS rules to the Hypercode structure, and executes the resulting program.

### 3.2 Terminology

* **Hypercode (.hc)** — A declarative file describing the logical structure of a program in an indented, hierarchical format.
* **Hypercode Cascade Sheet (HCS, .hcs)** — A YAML-compatible file that configures Hypercode entities using selectors.
* **Selector** — A mechanism for addressing elements in a Hypercode file: by type, class, ID, or structural position (similar to CSS selectors).
* **Rule (`@env[...]`)** — A context-aware rule group activated when a specific condition is met.
* **Execution Context** — The environment that determines which HCS rules are active (e.g., `env=production`).
* **Resolution Algorithm** — The process for resolving applicable rules based on specificity, precedence, and cascading logic.

## 4. Syntax and Semantics

### 4.1. Hypercode Syntax

The syntax is minimal and based on indentation. Each line represents a command or entity. Commands can be augmented with **class** (`.`) and **id** (`#`) markers for targeting by the HCS.

```hypercode
# example.hc

Application
  Database.pooled#primary-db
    Connect
    Migrate
  Logger.file-logger
  WebServer#main-server
    Listen
    RegisterRoutes
      HealthCheck.public
      GetUsers.private
```

### 4.2. Hypercode Cascade Sheet (HCS) Syntax

The HCS uses a YAML-based syntax with special selectors to apply configuration data. Rules are applied based on specificity, with ID selectors being more specific than class selectors, which are more specific than type selectors.

#### 4.2.1. Selectors

*  **Type Selector:** Targets a command by its name.

    ```hcs
    Database:
      driver: “sqlite”
      in_memory: true
    ```

*  **Class Selector:** Targets all commands with a given class.

    ```hcs
    .pooled:
      pool_size: 20
    ```

*  **ID Selector:** Targets the single command with a unique ID.

    ```hcs
    ’#primary-db’:
      host: “override.db.host.com”
    ```

*  **Child Selector:** Targets direct children of a command.

    ```hcs
    WebServer > Listen:
      port: 8080
    ```

#### 4.2.2. Contextual Rules (`@rules`)

`@rules` allow entire sections of the HCS to be applied conditionally, based on the runtime environment. This is the core mechanism for context-awareness.

```hcs
# default.hcs

# Default configuration (e.g., for development)
Database:
  driver: "sqlite"
  path: "/var/tmp/dev.db"

WebServer > Listen:
  port: 3000

# --- Production Overrides ---
@env[production]:
  Database:
    driver: "postgresql"
    host: "${DB_HOST}" # Values can be interpolated from env vars
    user: "${DB_USER}"
    password: "${DB_PASS}"

  .pooled:
    pool_size: 100

  WebServer > Listen:
    port: 80
```

#### 4.2.3. Cascade and Specificity

The HCS resolution process follows a strict order of precedence, analogous to CSS:

1.  **Origin and Importance:** Rules applied from more specific sources (e.g., a user-provided override file) can take precedence over base rules.
2.  **Specificity:** A selector's specificity is calculated based on its components. From highest to lowest: ID (`#id`), Class (`.class`), Type (`Command`). A more specific selector always overrides a less specific one. (e.g., `#primary-db` overrides `.pooled`).
3.  **Source Order:** If two selectors have the same specificity, the one that appears later in the document wins.

When multiple rules match a single command, their properties are merged. Properties from higher-specificity rules override those from lower-specificity rules.

## 5. Example: A Simple Web Service

This example demonstrates how a single Hypercode file can be configured for both development and production environments using an HCS file.

```hypercode
# app.hc (The logic structure is constant)

Service
  Logger.console
  Database#main-db
    Connect
  APIServer
    Listen
```

```hcs
# config.hcs (Provides context-dependent behavior)

# --- Default/Development Settings ---
Logger:
  level: "debug"

.console:
  format: "text"

Database:
  driver: "sqlite"
  file: "dev.sqlite3"

APIServer > Listen:
  host: "127.0.0.1"
  port: 5000

# --- Production Environment Overrides ---
@env[production]:
  Logger:
    level: "info"

  .console:
    format: "json" # Switch to structured logging for production

  '#main-db':
    driver: "postgres"
    connection_string: "${DATABASE_URL}" # Use environment variable
    pool_size: 50

  APIServer > Listen:
    host: "0.0.0.0"
    port: 8080
```

**Execution:**

 *  Runs the app with the development SQLite database:

 ```bash
 hypercode-runner app.hc --hcs config.hcs
 ```

 *  Runs the same app, but it now uses a PostgreSQL database and logs in JSON format. The core logic in `app.hc` remains untouched:

 ```bash
 hypercode-runner app.hc --hcs config.hcs --ctx env=production
 ```

 ## 6. Compatibility and Interoperability

 Hypercode is designed to be environment-agnostic and compatible with a variety of runtimes and deployment systems. Potential integrations include:

 - Embedding HCS resolution in Kubernetes Admission Controllers.
 - Generating `.env` files from rules for legacy apps.
 - Translating Hypercode into Terraform modules via adapters.

## 7. Media Types and File Extensions

- File extensions: `.hc`, `.hcs`
- Suggested MIME type: `application/hypercode+yaml`

## 8. Security Considerations

Hypercode and HCS are declarative and do not define runtime execution isolation or sandboxing. If used in multi-tenant environments, additional security measures (e.g., containerization, seccomp, chroot) should be applied externally.

The specification assumes that the resolution and execution engine is trusted. No mechanisms are currently defined for verifying integrity of `.hcs` rules or controlling their provenance. Future versions may include digital signing or validation capabilities.

## 9. Novelty and Prior Art

### 9.1. The Claim

No single ingredient of Hypercode is new. Selectors, cascading configuration, dependency graphs, code generation, and specification-driven development each have mature prior art. The claim is narrower, and deliberately falsifiable:

> We have not found a mainstream specification or tooling stack that combines, in one format: (1) a stable, addressable application topology; (2) CSS-like selector rules over that topology; (3) deterministic cascade resolution with specificity and context rules; (4) first-class provenance for every resolved property; and (5) a versioned resolved IR designed for explanation, semantic diffing, validation, and incremental — including AI-assisted — code generation.

Hypercode is therefore a new *combination* and a new *layer* — a context-resolved specification layer between human-reviewed architectural intent and deterministic or AI-assisted code generation — not a wholly new idea.

### 9.2. What Hypercode Is Not

* **Not a replacement for typed configuration languages.** CUE, Dhall, Nickel, Pkl, KCL, and Jsonnet are mature at validating and generating configuration *data*, with strong type systems, contracts, and tooling. Hypercode does not compete on those axes today (see §9.8); its subject is an addressable *topology* and the rules that target it, not standalone data.
* **Not model-driven architecture.** The "executable architecture" lineage (MDA, executable BPMN, TOSCA) expects the model to be complete enough that systems can be derived from it mechanically; in practice the models grew as complex as the code, and round-trip synchronization failed. A `.hc` file is deliberately *incomplete*: a skeleton plus context policies, with algorithmic detail left to host code or to a generator.
* **Not a natural-language specification format.** AGENTS.md, Kiro specs, and GitHub Spec Kit guide coding agents with Markdown. Hypercode is positioned *underneath* such documents: the part of a specification that must resolve deterministically, diff semantically, and carry provenance.
* **Not an interface contract or agent protocol.** OpenAPI, AsyncAPI, and GraphQL describe service boundaries; MCP and A2A standardize agent interoperability. Hypercode nodes may *reference* such contracts as properties. Generating or replacing them is an explicit non-goal: pulling interface schemas into `.hcs` would recreate the completeness pressure that bloated MDA models.

### 9.3. Prior Art Map

| Segment | Representative tools | What they solve | Relation to Hypercode |
|---|---|---|---|
| Typed configuration languages | CUE, Dhall, Nickel, Pkl, KCL, Jsonnet | validation, schemas, DRY configuration generation | Hypercode adds an addressable topology with cascade and provenance semantics; it does not yet match their type systems |
| Deployment overlays | Helm, Kustomize, kpt | packaging and per-environment overlays for Kubernetes manifests | the same pain (multi-environment duplication), but overlays target manifests, and "why is this value here?" is answered by archaeology; Hypercode makes provenance part of resolution semantics |
| Application models | OAM / KubeVela | separating developer components from operator traits and policies over an application topology | the closest structural analog — a two-artifact split over an application topology; OAM is Kubernetes-specific and has no specificity cascade, no property-level provenance, and no codegen-oriented IR |
| DI / wiring | Spring, Guice, Dagger | object-graph wiring, including compile-time code generation | declarative composition roots and AOT wiring are not new; Hypercode adds context resolution, provenance, and stable language-agnostic anchors |
| Architecture as code | Structurizr / C4, TOSCA, BPMN | modeling, documentation, orchestration | these model or document systems; Hypercode aims at a codegen-ready resolved IR with provenance |
| Interface contracts | OpenAPI, AsyncAPI, GraphQL | service-boundary contracts | adjacent layers: Hypercode nodes reference these contracts; generating them is a non-goal (§9.2) |
| Runtime feature flags | OpenFeature, LaunchDarkly | dynamic, per-request flag evaluation against runtime contexts | a different binding time: flags decide values at runtime, Hypercode resolves at build/generation time into an IR (§9.8); the layers compose rather than compete |
| Agent protocols & instructions | MCP, A2A, AGENTS.md | agent interoperability; coding-agent guidance | orthogonal; Hypercode can be the formal artifact such agents consume |
| AI spec-driven development | GitHub Spec Kit, Kiro | natural-language specifications as the source of truth for code generation | shared thesis ("code as regenerated output"); Hypercode contributes the formally resolvable, diffable, provenance-carrying layer that Markdown cannot provide |
| Software product lines (academic) | feature models (FODA), delta-oriented programming, CVL | one structure, many variants | white-label contexts are a product-line scenario; to our knowledge, cascade-with-specificity over context dimensions has not been explored as a variability mechanism in that literature |

### 9.4. Why Cascade — the Override Objection

The strongest objection to Hypercode's design comes from the configuration-language community itself. Drawing on Google's experience with GCL — where inheritance and overrides became a chronic source of configuration bugs — the designers of CUE made unification order-independent and *forbade* overrides entirely: in CUE, the origin of a value is never in doubt precisely because no rule can silently replace another. Hypercode deliberately reintroduces overriding, so the choice requires a defense. It has four parts:

1. **Determinism is machine-checked, not promised.** Cascade resolution (specificity, then source order) is specified operationally ([resolution semantics](../EBNF/Hypercode_Resolution.md)) and cross-checked by an executable [Lean 4 oracle](../SPEC/lean/). Resolution is independent of rule application and traversal order: the outcome is fully determined by the pair (specificity, source order).
2. **Provenance is core semantics, not optional tooling.** Every resolved property records its winning selector and source line as part of the [IR contract](../Schema/hypercode-ir-v1.schema.json), not as an add-on. The CSS cascade became manageable the day developer tools showed where each style came from; Hypercode bakes that affordance into the format. The `hypercode explain` command surfaces the full match trace, including losing rules with their specificity and source order.
3. **Values cascade; contracts only narrow.** The contract layer (property schemas attached via selectors in `@contract:` blocks) is monotonic in CUE's spirit. Its governing rule:

   > A more specific selector **MAY** override a value.
   > A more specific selector **MUST NOT** weaken a contract established by a less specific rule; weakening is a resolution error.

   For example, given a base contract `Database: pool_size: int >= 1`, a more specific `Database#main: pool_size: int >= 10` is valid (narrowing), while `Database#main: pool_size: int >= 0` is rejected (weakening). Behavior cascades; safety does not. This asymmetry is the design's direct answer to the GCL lesson.

   Two refinements make the rule precise (normative semantics in the [resolution specification](../EBNF/Hypercode_Resolution.md)). First, contracts **accumulate by intersection**: every contract matching a node governs it simultaneously, and an omitted bound is not a statement — it inherits through the intersection. Second, as in the CSS cascade, specificity relates two contracts only when at least one node in the document is matched by both selectors; contracts on disjoint parts of the tree are independent. Monotonicity violations are resolution errors (HC2101 type change, HC2102 interval widening, HC2103 required→optional); validating resolved *values* against the effective contract is the next layer (HC2104, in progress).
4. **Known failure modes are acknowledged.** Specificity wars and selector escalation are real CSS pathologies at scale. Countermeasures — origin/layer control analogous to CSS `@layer`, dangling-selector validation (already in `hypercode validate`), and explain tooling — are sequenced in the [work plan](../workplan.md) ahead of language surface that would amplify them.

### 9.5. Why a Stable Topology

Selector rules need something stable to address. `.hc` exists to provide exactly that: a small, versioned, addressable graph whose nodes (`type`, `.class`, `#id`) act as anchors. Those anchors serve every downstream consumer at once: `.hcs` rules target them, generated code can be tagged with the node it implements, validators map findings back to them, and diffs of the resolved graph identify affected modules. Without a stable topology, provenance, semantic diffing, and incremental regeneration lose their reference frame — which is why the structure is a separate artifact rather than keys scattered through configuration data.

### 9.6. Why Provenance

In layered configuration systems the recurring operational question is "where did this value come from?", and it is answered by archaeology across charts, overlays, and profiles. Hypercode's resolver answers it as part of its output: every resolved property carries the selector and source line that won the cascade. Provenance turns the specification from text into an audit and debugging artifact. For AI-assisted generation it does further work: a validator that finds nonconforming generated code can state which rule demanded the behavior, and generated tests can carry their provenance as comments — making the cascade an auditable trail rather than an opaque merge.

### 9.7. Why AI Code Generation

Spec-driven development is converging on the view that the specification is the durable artifact and code is increasingly a regenerated output. Today that movement runs almost entirely on natural-language Markdown, which neither resolves deterministically nor diffs semantically. Hypercode's intended role is the formal substrate underneath it, with three consequences:

* **Confined nondeterminism.** The specification side resolves deterministically (machine-checked, §9.4); nondeterminism is confined to the generation step, where it can be validated against the resolved graph.
* **A fixed generated/durable boundary.** Classic MDA demanded complete models; an LLM generator tolerates incompleteness, so `.hc` can stay a skeleton. The node boundary fixes the division of labor: orchestration and wiring are derived from the resolved graph (mechanically where possible), while durable leaf implementations live behind generated interfaces and are never overwritten. Node-level hashes over the resolved IR (`hypercode.ir/v2`, [schema](../Schema/hypercode-ir-v2.schema.json)) provide the invalidation signal for incremental regeneration: the hash covers the stable resolved content — type, class, id, resolved values, child hashes — so a provenance-only change (a different rule winning with the same value) does not invalidate.
* **Review compression.** The unit of human review shifts from generated code to the specification diff: humans approve a small, formally resolved change; machines expand it into code and validate the expansion against the same graph.

### 9.8. Acknowledged Limits

* **Context binds at resolve time.** `--ctx` is supplied when resolving: Hypercode's default mode decides context at build/generation time. Runtime feature-flag systems (OpenFeature, LaunchDarkly) decide flag values per request at runtime — a different layer that composes with Hypercode rather than competing with it. Serving dynamic context from a single deployment (e.g., many tenants per process) would require embedding the resolver as a runtime library; that optional mode raises its own caching, latency, and provenance questions and is currently out of scope.
* **No integrity chain yet.** As noted in §8, nothing verifies the chain end-to-end: signed `.hc`/`.hcs` → resolved-IR hash → generator identity and version → generated-artifact hashes → validator report. SLSA provides the reference vocabulary for such attestations. For the review-compression story to carry governance weight they are eventually required; they are deliberately deferred as future work.
* **Type-system maturity.** IR v2 carries typed values (string/int/double/bool, inferred at parse time with the source lexeme preserved), and the contract layer (§9.4) ships declarations and monotonicity validation. Enforcement of resolved values against the effective contract (HC2104) is in progress; until it lands, Hypercode still does not compete with typed configuration languages on safety. IR v1 remains strings-only and is kept for backward compatibility.

## 10. Open Questions

*  **Debugging and Tooling:** How can developers effectively trace why a specific configuration was applied? This would require specialized debugging tools that can visualize the cascade and resolution of HCS rules.
*  **Performance:** The overhead of parsing and resolving the HCS at startup needs to be analyzed. A JIT (Just-In-Time) resolution or an AOT (Ahead-Of-Time) compilation step might be necessary for performance-critical applications.
*  **Complexity Management:** While HCS simplifies the core logic, very large and complex HCS files could become difficult to manage themselves. Best practices and modularization strategies would be required. This could include extending the at-rule system with directives like `@import`, allowing for better organization of large configurations.

## 11. References

* [Hypercode Syntax Specification (BNF)](../EBNF/Hypercode_Syntax.md)
* [W3C CSS 2.1 Specification](https://www.w3.org/TR/CSS21/)
* [YAML 1.2 Spec (OASIS)](https://yaml.org/spec/1.2/)
* [Spring Framework: Dependency Injection](https://docs.spring.io/spring-framework/reference/core/beans/)
* [Terraform Configuration Language](https://developer.hashicorp.com/terraform/language)

Prior art surveyed in §9:

* [CUE](https://cuelang.org/) · [Pkl](https://pkl-lang.org/) · [Dhall](https://dhall-lang.org/) · [Nickel](https://nickel-lang.org/) · [KCL](https://www.kcl-lang.io/) · [Jsonnet](https://jsonnet.org/) — typed configuration languages
* [Helm](https://helm.sh/) · [Kustomize](https://kustomize.io/) — deployment overlays
* [Open Application Model](https://oam.dev/) · [KubeVela](https://kubevela.io/) — application models
* [Structurizr DSL](https://docs.structurizr.com/dsl) · [OASIS TOSCA](https://www.oasis-open.org/committees/tosca/) · [OMG BPMN](https://www.omg.org/spec/BPMN/) — architecture as code
* [OpenAPI](https://www.openapis.org/) · [AsyncAPI](https://www.asyncapi.com/) — interface contracts
* [Model Context Protocol](https://modelcontextprotocol.io/) · [A2A](https://a2a-protocol.org/) · [AGENTS.md](https://agents.md/) — agent protocols & instructions
* [OpenFeature](https://openfeature.dev/) · [LaunchDarkly](https://launchdarkly.com/) — runtime feature flags
* [GitHub Spec Kit](https://github.com/github/spec-kit) · [Kiro](https://kiro.dev/) · [Martin Fowler — Exploring Gen AI / spec-driven development](https://martinfowler.com/articles/exploring-gen-ai.html) — AI spec-driven development
* [SLSA](https://slsa.dev/) — supply-chain attestation vocabulary (deferred integrity work, §9.8)
* Kang et al., *Feature-Oriented Domain Analysis (FODA)*, CMU/SEI-90-TR-021, 1990 · Pohl, Böckle & van der Linden, *Software Product Line Engineering*, Springer, 2005 — software product lines

## 12. Change Log

**Version 0.2** (2026-06-11):

* Contracts are now part of the language model (HC-111): `@contract:` block syntax in `.hcs`, accumulation by intersection (an omitted bound inherits), specificity relating only contracts that can govern the same node, monotonicity diagnostics HC2101–HC2103 (§9.4); value-level enforcement (HC2104) declared in progress.
* `hypercode explain` (HC-110) shipped: full cascade trace with winner and losing rules (§9.4).
* `hypercode.ir/v2` (HC-112) shipped: typed values with lexeme preservation, winner/losers per property, contract echo, per-node and per-document SHA-256 hashes over stable resolved content (§9.7, §9.8).
* Normative contract semantics delegated to the resolution specification (`EBNF/Hypercode_Resolution.md` §7).

**Version 0.1.1** (2026-06-10):

* Replaced §9 "Comparison to Existing Concepts" with "Novelty and Prior Art": the novelty claim stated as a falsifiable combination; non-goals; a prior-art map (typed configuration languages, deployment overlays, OAM/KubeVela, DI, architecture-as-code, interface contracts, agent protocols, AI spec-driven development, software product lines); the override objection and its answer, including the *values cascade, contracts only narrow* rule; rationale for stable topology, provenance, and AI code generation; acknowledged limits.
* Extended §11 References with the surveyed prior art.
* Stated the cascade-safety rule normatively (§9.4): a more specific selector MAY override a value, MUST NOT weaken an inherited contract.
* Drew the runtime boundary (§9.3, §9.8): build/generation-time resolution by default vs. runtime feature flags (OpenFeature, LaunchDarkly); embedded runtime resolution noted as an optional, out-of-scope mode.
* Named SLSA as the reference vocabulary for the deferred integrity/attestation chain (§9.8).

**Version 0.1** (2025-07-12):

* Initial public draft with definition of Hypercode, HCS, selectors, rules, and example syntax.
