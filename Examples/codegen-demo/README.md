# HC-124 — End-to-end AI codegen demo

The runnable version of the pipeline from [RFC §9.7](../../RFC/Hypercode.md)
and [DOCS/Usage.md §5](../../DOCS/Usage.md): the spec is the durable artifact,
code is regenerated output, and the resolved graph sits between them.

```
Examples/service.{hc,hcs} ──▶ IR v2 ──▶ generated/*.py   (one module per node)
            │                   │              │
        1-line edit        node hashes     check.py validates artifacts
       (review this!)    (what changed?)   against the same contracts
```

Every module in [`generated/`](generated/) was produced by Claude from the
production-context IR of [`Examples/service.{hc,hcs}`](../service.hc). Each
embeds the **hash of its source node** and every value carries its
**provenance** as a comment:

```python
# node: /Service/APIServer
# hash: 7da0acd4b1617ed3…
CONFIG = {
    "port": 8080,    # APIServer > Listen @ Examples/service.hcs:26
}
```

## 1. Verify: artifacts match the spec

```console
$ python3 check.py
  FRESH  api_server.py    /Service/APIServer
  FRESH  database.py      /Service/Database
  FRESH  logger.py        /Service/Logger
  FRESH  service.py       /Service

all modules fresh and contract-conformant
```

`check.py` re-emits the IR and does two things: compares each module's
embedded node hash against the current one (**freshness**), and validates the
values embedded in the generated code against the `contracts[]` echoed in the
IR (**conformance**). CI runs this on every push.

## 2. Scoped regeneration: a one-line spec edit

```console
$ sed 's/port: 8080/port: 9090/' ../service.hcs > /tmp/edited.hcs
$ python3 check.py --hcs /tmp/edited.hcs
  STALE  api_server.py    /Service/APIServer
  FRESH  database.py      /Service/Database
  FRESH  logger.py        /Service/Logger
  STALE  service.py       /Service

2 module(s) stale — regenerate with generate.sh
```

The port lives on the `Listen` node, so exactly `api_server.py` is stale —
plus the root wiring, because a node's hash is a Merkle hash over its subtree.
`logger.py` and `database.py` are untouched and **not** regenerated. This is
the review-compression loop: a human reviews the one-line spec diff; the
machine knows precisely which artifacts it invalidates.

## 3. Guardrails on both sides of generation

**Before** generation, the spec itself is gated — a bad edit never reaches
the generator:

```console
$ hypercode validate bad.hc --hcs bad.hcs --ctx env=production
bad.hcs:1:1: error[HC2104]: contract violation for 'port': 99999 exceeds upper bound 65535.0 …
```

**After** generation, the artifacts are checked against the same contracts.
Hand-edit `generated/api_server.py` to `"port": 99999` and:

```console
$ python3 check.py
contract violations in generated artifacts:
  error[HC2104-gen] api_server.py: 'port' = 99999 exceeds 65535.0 (contract 'APIServer > Listen')
$ echo $?
2
```

The contract written once in the `.hcs` governs the spec, the resolved graph,
and the generated code.

## 4. Regenerate with Claude

```console
$ ./generate.sh            # needs the `claude` CLI
regenerating api_server.py from node /Service/APIServer …
```

`check.py --list-stale` scopes the work; `generate.sh` feeds Claude the IR
subtree of each stale node (the source of truth) plus the module conventions,
then re-runs the checks. No stale module — no LLM call.

The same comparison is available as a compiler command: `hypercode diff
old.ir.json new.ir.json` reports the affected nodes with the old and new
winning rules (see [DOCS/Usage.md §6](../../DOCS/Usage.md)).

## 5. It actually runs

```console
$ python3 generated/service.py
('0.0.0.0', 8080)
```

## Files

| File | Role |
|---|---|
| `check.py` | freshness (node hashes) + contract conformance of artifacts |
| `generate.sh` | scoped regeneration of stale modules via `claude -p` |
| `generated/*.py` | the generated service — one module per `.hc` node |
