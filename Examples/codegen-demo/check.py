#!/usr/bin/env python3
"""HC-124 demo: verify generated modules against the Hypercode resolved graph.

Two independent checks, stdlib only:

  1. Freshness — each module embeds the hash of the IR node it was generated
     from. Node hashes cover the stable resolved content (Merkle over the
     subtree), so a hash mismatch means the spec changed underneath the module
     and it must be regenerated. This is the invalidation signal that scopes
     regeneration: only stale modules are rebuilt.

  2. Contract conformance — values embedded in generated code are validated
     against the contracts[] echoed in the IR (type, bounds, required). Even a
     hand-edited "generated" file that smuggles in port: 99999 is caught.

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


def index_nodes(ir):
    """path -> node, depth-first."""
    nodes = {}

    def walk(node, path):
        path = f"{path}/{node['type']}"
        nodes[path] = node
        for child in node["children"]:
            walk(child, path)

    for root in ir["nodes"]:
        walk(root, "")
    return nodes


def subtree_properties(node):
    """All resolved properties in a node's subtree: key -> property entry."""
    props = {}

    def walk(n):
        props.update(n["properties"])
        for child in n["children"]:
            walk(child)

    walk(node)
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

    stale, violations = [], []
    gen_dir = os.path.join(HERE, "generated")
    for name in sorted(os.listdir(gen_dir)):
        if not name.endswith(".py"):
            continue
        node_path, embedded, config = parse_module(os.path.join(gen_dir, name))
        node = nodes.get(node_path)
        if node is None:
            sys.exit(f"{name}: node '{node_path}' no longer exists in the IR")
        fresh = node["hash"] == embedded
        if not fresh:
            stale.append(name)
        violations += check_contracts(config, subtree_properties(node), name)
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
