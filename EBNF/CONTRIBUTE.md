# CONTRIBUTING.md

# Contributing to Hypercode

Welcome! We gladly accept contributions to the **Hypercode grammar, specification, tooling, and examples**.

## Branching Model

We use a **staged Git workflow**:

| Branch         | Purpose                                |
|-|-|
| `main`         | Stable, tagged releases (e.g. `v0.2.0`) |
| `develop`      | Next release in progress               |
| `feature/*`    | Experimental or isolated improvements  |
| `spec/*`       | Changes to the formal specification    |

## Developing the Grammar

1. Clone the repo:

```bash
git clone https://github.com/0AL/Hypercode.git
cd Hypercode/grammar
```

2.	Create a new branch:

```
git switch develop
git switch -c feature/your-topic
```

3.	Make your changes:

•	Edit `.g4` grammar files
•	Add `.hc` test cases to `hypercode_tests/`
•	Use `make test-all` to verify correctness

4.	Run tests locally:

```
make
make test-all
```

5.	Submit a Pull Request into develop.

Working on the RFC

If you’re improving the spec (`docs/RFC.md`), use a spec/ branch:

```
git switch -c spec/clarify-nesting-rules
```

Requirements for Merge

•	CI (`make test-all`) must pass
•	New grammar features must be tested
•	Version in `spec-version.txt` must be bumped (e.g. `0.3.0-alpha`)
•	If relevant, `CHANGELOG.md` must be updated

Thank You!

Every contribution helps make Hypercode a better tool for declarative programming!
