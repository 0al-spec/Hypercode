# Hypercode — Swift reference implementation

A hand-written lexer + recursive-descent parser for the Hypercode `.hc` format,
with **no ANTLR / JVM dependency**. Indentation is handled with an explicit
indent stack that emits synthetic `indent` / `dedent` tokens (the off-side rule),
matching the grammar in [../EBNF/Hypercode_Syntax.md](../EBNF/Hypercode_Syntax.md).

## Requirements

- Swift 5.9+ (tested on Swift 6.2)

## Usage

```bash
cd swift
swift build
swift test
swift run hypercode ../EBNF/hypercode_tests/03-nesting.hc
```

Example output:

```
Application
  Form
    Input (class: text, id: name)
    Input (class: password, id: pass)
  Button (class: primary, id: submit)
```

## Layout

```
swift/
├── Package.swift
├── Sources/
│   ├── Hypercode/            # library: Token, Lexer, AST (Command), Parser
│   └── HypercodeCLI/         # `hypercode` CLI: parse a .hc file, print the tree
└── Tests/HypercodeTests/     # cases ported from EBNF/hypercode_tests/*.hc
```

## Status / roadmap

- [x] `.hc` lexer (indent / dedent)
- [x] `.hc` parser → `Command` AST
- [x] CLI: parse and print the tree
- [ ] `.hcs` (cascade sheet) parser
- [ ] cascade resolver (`.hc` + `.hcs` → resolved graph), per RFC §4.2
- [ ] generic emit of the resolved graph
