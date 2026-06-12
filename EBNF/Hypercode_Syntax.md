# Hypercode Syntax Specification (BNF)

**Status:** Draft

**Version:** 0.2

**Date:** June 11, 2026

**Author:** Egor Merkushev

**License:** MIT

## Overview

This document defines the formal syntax of the Hypercode `.hc` file format using a Backus–Naur Form (BNF) grammar.

The goal is to provide an unambiguous reference for tool developers, parser authors, and implementers of Hypercode engines.

## 1. BNF Grammar

```bnf
<hypercode>      ::= { <command-line> }
<command-line>   ::= <command> <newline> [<block>]
<command>        ::= <identifier> [<class>] [<id>]
<class>          ::= "." <identifier>
<id>             ::= "#" <identifier>
<block>          ::= <INDENT> { <command-line> } <DEDENT>
<identifier>     ::= <letter> { <letter> | <digit> | "_" | "-" }
<letter>         ::= "A" | ... | "Z" | "a" | ... | "z"
<digit>          ::= "0" | ... | "9"
<newline>        ::= "\n"
<INDENT>         ::= (synthetic token emitted by the lexer when <indent> depth increases)
<DEDENT>         ::= (synthetic token emitted by the lexer when <indent> depth decreases)
<indent>         ::= <spaces> | <tabs>
<spaces>         ::= <space> { <space> }
<tabs>           ::= <tab> { <tab> }
<space>          ::= " "
<tab>            ::= "\t"
```

## 2. Example Input

```hypercode
App
  Logger.console
  Database.pooled#primary-db
    Connect
    Migrate
  WebServer#main
    Listen
    RegisterRoutes
      HealthCheck.public
      GetUsers.private
```

## 3. AST Representation (Indented)

```
App
├── Logger (class: console)
├── Database (class: pooled, id: primary-db)
│   ├── Connect
│   └── Migrate
└── WebServer (id: main)
    ├── Listen
    └── RegisterRoutes
        ├── HealthCheck (class: public)
        └── GetUsers (class: private)
```

## 4. Test Cases

### ✅ Valid

#### Case 1: Simple nesting

```hypercode
Service
  SubService
    Task
```

#### Case 2: With class and id

```hypercode
Worker.task#main
```

### ❌ Invalid

#### Case 3: Misaligned indentation

```hypercode
Root
   Sub  ← inconsistent indent (3 spaces?)
```

#### Case 4: Invalid identifier

```hypercode
@bad#id
```

## 5. Notes

- Identifiers must not contain whitespace or special symbols.
- Indentation must be consistent (e.g., 2 or 4 spaces, or tabs—but not mixed).
- Indentation is significant (off-side rule): a nested `<block>` must be indented deeper than its parent `<command-line>`. The lexer reads each line's leading `<indent>`, tracks it on an indentation stack, and emits the synthetic `<INDENT>` / `<DEDENT>` tokens when the depth increases or decreases. Because this context-sensitive relationship cannot be expressed in pure BNF, indentation handling is delegated to the lexer (see `HypercodeLexer.g4`).
- No support for inline attributes or arguments in `.hc` files (these belong in `.hcs`).

## 6. `.hcs` Cascade Sheet Syntax

A `.hcs` file contains cascade rules and optional contract blocks.

### 6.1 Cascade Rule

```
<sheet>           ::= { <top-level-block> }
<top-level-block> ::= <dimension-block> | <contract-block> | <rule-block>

<dimension-block> ::= "@" <identifier> "[" <value> "]" ":" <newline>
                       <INDENT> { <rule-block> } <DEDENT>
<value>           ::= <identifier>

<rule-block>      ::= <selector> ":" <newline>
                       <INDENT> { <property-line> } <DEDENT>
<property-line>   ::= <identifier> ":" <scalar> <newline>
<scalar>          ::= <quoted-string> | <bare-scalar>
<quoted-string>   ::= '"' { <char> } '"' | "'" { <char> } "'"
<bare-scalar>     ::= any run of characters up to end of line (trimmed)
```

A bare scalar is type-inferred by the reader: `true`/`false` → bool, integral
form → int, decimal form without letters → double, anything else → string
(e.g. `driver: sqlite` is a valid bare string). Quoting forces string. The
source lexeme is preserved verbatim for v1 IR round-tripping.

### 6.2 Selectors

```
<selector>        ::= <simple-selector> { ">" <simple-selector> }
<simple-selector> ::= <type-sel> | <class-sel> | <id-sel>
<type-sel>        ::= <identifier>
<class-sel>       ::= "." <identifier>
<id-sel>          ::= "#" <identifier>
```

Specificity (highest to lowest): id `#x` > class `.x` > type `x`.

### 6.3 `@contract:` Block (HC-111)

A `@contract:` block declares property constraints for nodes matching a selector.
More-specific selectors may only **narrow** constraints — never widen them (monotonicity invariant).

```
<contract-block>  ::= "@contract:" <newline>
                       <INDENT> { <contract-selector> } <DEDENT>

<contract-selector> ::= <selector> ":" <newline>
                         <INDENT> { <constraint-line> } <DEDENT>

<constraint-line> ::= <constraint-key> ":" <constraint-type>
                       [ ">=" <number> ] [ "<=" <number> ] <newline>

<constraint-key>  ::= <identifier> [ "[?]" ]   // "[?]" marks optional property
<constraint-type> ::= "string" | "int" | "float" | "bool"
```

#### Constraint syntax example

```hcs
@contract:
  service:
    timeout[?]: int >= 1 <= 300
    name: string
  .primary:
    timeout: int >= 10 <= 200   # narrows — allowed
```

#### Semantics

How contracts accumulate, intersect, and which monotonicity violations are
diagnostics (HC2101–HC2103) is defined in the
[resolution semantics](Hypercode_Resolution.md) — this document covers syntax
only.

## 7. Future Work

- Define EBNF with optional comments, arguments, and macro support.
- Add parser conformance test suite.
- Define formal AST schema (YAML or JSON).

## 8. Change Log

**Version 0.2** (2026-06-11)

* Added Section 6: `.hcs` cascade sheet syntax (rules, selectors, dimension blocks).
* Added `@contract:` block grammar (HC-111): constraint-line syntax, `[?]` optional marker, bounds `>=`/`<=`.
* Bare scalars documented (type inference, lexeme preservation); semantics
  (contract accumulation, monotonicity diagnostics) live in
  `Hypercode_Resolution.md`.

**Version 0.1** (2025-07-12)

* Initial public draft of the Hypercode grammar in BNF.
* Describes core structural elements: command, class, ID, indentation-based hierarchy.
