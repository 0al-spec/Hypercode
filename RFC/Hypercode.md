# Hypercode: A Declarative Paradigm for Context-Aware Programming

**Status:** Draft

**Version:** 0.1

**Date:** July 8, 2025

**Author:** Egor Merkushev

**Licence:** MIT

## Status of this Document

This document is a **draft specification** for the Hypercode programming paradigm. It is intended to introduce the core concepts, syntax, and execution model of Hypercode and its companion format, Hypercode Cascade Sheets (HCS). The purpose of this draft is to facilitate discussion and gather feedback from the broader developer, systems, and programming language communities.

This is **not yet a finalized standard**, and details in syntax, behavior, or terminology are subject to change. Implementers are advised to treat this version as **experimental** and to expect updates as the model evolves based on practical feedback and further validation.

Feedback and contributions are welcome via the [project’s GitHub repository](https://github.com/0al-spec/hypercode) or issue tracker.

This document is released under the MIT License and follows open specification principles, similar in spirit to community-driven RFCs.

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

*  **Hypercode (`.hc` file):** A file describing the application's logical structure using simple, indentation-based hierarchy. It contains abstract commands or entities. It is analogous to an HTML document's structure. See [Hypercode Syntax Specification](./hypercode-syntax.md) for the formal grammar of `.hc` files.

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
 hypercode-runner app.hc --hcs config.hcs --env production
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

## 9. Comparison to Existing Concepts

*  **Dependency Injection (DI):** Hypercode can be seen as a form of declarative, externalized DI. Unlike traditional DI containers configured via XML or annotations, HCS provides a more expressive and dynamic configuration mechanism through selectors and @rules.
*  **Templating Engines (e.g., Jinja, Handlebars):** While similar, templating engines typically generate static text or configuration files. Hypercode is concerned with generating and configuring a live, executable program graph.
*  **Infrastructure as Code (IaC, e.g., Ansible, Terraform):** Hypercode shares the declarative philosophy of IaC tools but applies it to the application logic itself, rather than to the underlying infrastructure. It defines the application's runtime behavior, not just its deployment environment using HCS.

## 10. Open Questions

*  **Debugging and Tooling:** How can developers effectively trace why a specific configuration was applied? This would require specialized debugging tools that can visualize the cascade and resolution of HCS rules.
*  **Performance:** The overhead of parsing and resolving the HCS at startup needs to be analyzed. A JIT (Just-In-Time) resolution or an AOT (Ahead-Of-Time) compilation step might be necessary for performance-critical applications.
*  **Complexity Management:** While HCS simplifies the core logic, very large and complex HCS files could become difficult to manage themselves. Best practices and modularization strategies would be required. This could include extending the at-rule system with directives like `@import`, allowing for better organization of large configurations.

## 11. References

* [Hypercode Syntax Specification (BNF)](https://github.com/0al/hypercode/hypercode-syntax.md)
* [W3C CSS 2.1 Specification](https://www.w3.org/TR/CSS21/)
* [YAML 1.2 Spec (OASIS)](https://yaml.org/spec/1.2/)
* [Spring Framework: Dependency Injection](https://docs.spring.io/spring-framework/reference/core/beans/)
* [Terraform Configuration Language](https://developer.hashicorp.com/terraform/language)

## 12. Change Log

**Version 0.1** (2025-07-12):

* Initial public draft with definition of Hypercode, HCS, selectors, rules, and example syntax.
