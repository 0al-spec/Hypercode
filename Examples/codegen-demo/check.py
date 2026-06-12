#!/usr/bin/env python3
"""HC-124 demo: verify generated modules against the Hypercode resolved graph.

Two independent checks, stdlib only:

  1. Freshness — each module embeds the hash of the IR node it was generated
     from. Node hashes cover the stable resolved content (Merkle over the
     subtree), so a hash mismatch means the spec changed underneath the module
     and it must be regenerated. This is the invalidation signal that scopes
     regeneration: only stale modules are rebuilt.

  2. Contract conformance — values embedded in generated code are validated
     against the contracts[] echoed in the IR: type and bounds for present
     keys, presence for required contracted keys, and no CONFIG key may exist
     outside the resolved spec. Even a hand-edited "generated" file that
     smuggles in port: 99999 — or drops port entirely — is caught.

Each module owns its node's subtree up to the boundary of the next generated
module (service.py owns /Service but not /Service/Logger.console, which
logger.py owns). Node paths use selector identity (type[.class][#id]) — the
same addressing as `hypercode diff`.

Exit codes: 0 = fresh & conformant, 1 = stale modules, 2 = contract violation.
"""
import argparse
import ast
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def emit_ir(hc, hcs, ctx):
    binary = os.environ.get(
        "HYPERCODE_BIN", os.path.join(REPO, ".build", "debug", "hypercode"))
    cmd = [binary, "emit", hc, "--hcs", hcs, "--format", "json"]
    for pair in ctx:
        cmd += ["--ctx", pair]
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO)
    if out.returncode != 0:
        sys.exit(f"emit failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def node_label(node):
    """Selector identity, same addressing as `hypercode diff`."""
    label = node["type"]
    if "class" in node:
        label += f".{node['class']}"
    if "id" in node:
        label += f"#{node['id']}"
    return label


def index_nodes(ir):
    """path -> node, depth-first; paths are /-joined selector identities."""
    nodes = {}

    def walk(node, path):
        path = f"{path}/{node_label(node)}"
        if path in nodes:
            sys.exit(f"ambiguous node path '{path}' — give same-type siblings"
                     " distinct classes or ids")
        nodes[path] = node
        for child in node["children"]:
            walk(child, path)

    for root in ir["nodes"]:
        walk(root, "")
    return nodes


def owned_properties(node, path, claimed):
    """Resolved properties of the subtree this module owns: its node's
    subtree, stopping at children that are themselves generated modules."""
    props = {}

    def walk(n, p):
        props.update(n["properties"])
        for child in n["children"]:
            child_path = f"{p}/{node_label(child)}"
            if child_path not in claimed:
                walk(child, child_path)

    walk(node, path)
    return props


def parse_module(path):
    """Extract the embedded node path, hash and CONFIG dict."""
    text = open(path).read()
    node = re.search(r"^# node: (.+)$", text, re.M)
    digest = re.search(r"^# hash: ([0-9a-f]{64})$", text, re.M)
    config = re.search(r"^CONFIG = (\{.*?\n\}|\{\})$", text, re.M | re.S)
    if not (node and digest and config):
        sys.exit(f"{os.path.basename(path)}: missing generated-module markers")
    return node.group(1), digest.group(1), ast.literal_eval(config.group(1))


TYPE_CHECK = {
    "int": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "float": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "string": lambda v: isinstance(v, str),
    "bool": lambda v: isinstance(v, bool),
}


def check_contracts(config, props, module):
    """Validate embedded values against the contracts echoed in the IR."""
    violations = []
    # Drift: a CONFIG key the spec doesn't resolve is a hand-edit, not output.
    for key in config:
        if key not in props:
            violations.append(
                f"{module}: '{key}' is not a resolved property of this"
                " module's nodes — not in the spec")
    # Presence: a key under a required contract must be carried by CONFIG.
    for key, prop in sorted(props.items()):
        if key in config:
            continue
        for contract in prop.get("contracts", []):
            if contract.get("required"):
                violations.append(
                    f"{module}: required '{key}' missing from CONFIG"
                    f" (contract '{contract['selector']}')")
                break
    for key, value in config.items():
        for contract in props.get(key, {}).get("contracts", []):
            sel = contract["selector"]
            if not TYPE_CHECK[contract["type"]](value):
                violations.append(
                    f"{module}: '{key}' = {value!r} is not {contract['type']}"
                    f" (contract '{sel}')")
                continue
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                if "min" in contract and value < contract["min"]:
                    violations.append(
                        f"{module}: '{key}' = {value} below {contract['min']}"
                        f" (contract '{sel}')")
                if "max" in contract and value > contract["max"]:
                    violations.append(
                        f"{module}: '{key}' = {value} exceeds {contract['max']}"
                        f" (contract '{sel}')")
    return violations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hc", default="Examples/service.hc")
    parser.add_argument("--hcs", default="Examples/service.hcs")
    parser.add_argument("--ctx", action="append", default=None,
                        help="key=value (default: env=production)")
    parser.add_argument("--list-stale", action="store_true",
                        help="print stale module filenames only")
    args = parser.parse_args()

    ir = emit_ir(args.hc, args.hcs, args.ctx or ["env=production"])
    nodes = index_nodes(ir)

    gen_dir = os.path.join(HERE, "generated")
    modules = [
        (name, *parse_module(os.path.join(gen_dir, name)))
        for name in sorted(os.listdir(gen_dir)) if name.endswith(".py")
    ]
    # Module boundaries: a node generated as its own module is not part of
    # its parent module's owned subtree.
    claimed = {node_path for _, node_path, _, _ in modules}

    stale, violations = [], []
    for name, node_path, embedded, config in modules:
        node = nodes.get(node_path)
        if node is None:
            sys.exit(f"{name}: node '{node_path}' no longer exists in the IR")
        fresh = node["hash"] == embedded
        if not fresh:
            stale.append(name)
        owned = owned_properties(node, node_path, claimed - {node_path})
        violations += check_contracts(config, owned, name)
        if not args.list_stale:
            status = "FRESH" if fresh else "STALE"
            print(f"  {status}  {name:16} {node_path}")

    if args.list_stale:
        print("\n".join(stale))
        return 1 if stale else 0

    if violations:
        print("\ncontract violations in generated artifacts:")
        for v in violations:
            print(f"  error[HC2104-gen] {v}")
        return 2
    if stale:
        print(f"\n{len(stale)} module(s) stale — regenerate with generate.sh")
        return 1
    print("\nall modules fresh and contract-conformant")
    return 0


if __name__ == "__main__":
    sys.exit(main())
