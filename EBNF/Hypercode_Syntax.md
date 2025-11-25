# Hypercode Syntax Specification (BNF)

**Status:** Draft

**Version:** 0.1

**Date:** July 12, 2025

**Author:** Egor Merkushev

**License:** MIT

## Overview

This document defines the formal syntax of the Hypercode `.hc` file format using a Backus–Naur Form (BNF) grammar.

The goal is to provide an unambiguous reference for tool developers, parser authors, and implementers of Hypercode engines.

## 1. BNF Grammar

```bnf
<hypercode>      ::= { <command-line> }
<command-line>   ::= <indent> <command> <newline> [<block>]
<command>        ::= <identifier> [<class>] [<id>]
<class>          ::= "." <identifier>
<id>             ::= "#" <identifier>
<block>          ::= <indent-block> { <command-line> }
<indent-block>   ::= <indent>+
<identifier>     ::= <letter> { <letter> | <digit> | "_" | "-" }
<letter>         ::= "A" | ... | "Z" | "a" | ... | "z"
<digit>          ::= "0" | ... | "9"
<indent>         ::= (one or more spaces or tabs)
<newline>        ::= "\n"
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
- No support for inline attributes or arguments in `.hc` files (these belong in `.hcs`).

## 6. Future Work

- Define EBNF with optional comments, arguments, and macro support.
- Add parser conformance test suite.
- Define formal AST schema (YAML or JSON).

## 7. Change Log

**Version 0.1** (2025-07-12)

* Initial public draft of the Hypercode grammar in BNF.
* Describes core structural elements: command, class, ID, indentation-based hierarchy.
* Includes:
  - EBNF grammar for `.hc` files
  - Visual AST example
  - Positive and negative test cases
  - Notes on scope and grammar limitations
