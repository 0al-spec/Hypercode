#!/usr/bin/env python3
"""HC-121 dogfooding: the worked example of DOCS/Backends.md, runnable.

Consumer-side adapter: emit the resolved IR v2 of examcalc.{hc,hcs}, map it
to a DomainOntologyPackage document (the Ontology repo's schema), and — with
--check — compare it *semantically* against the real, hand-written package
vendored in expected/ (a verbatim copy of
Ontology/SPECS/ontology/packages/examcalc/domain-ontology-package.yaml).

All schema knowledge (envelope constants, key names, list encodings) lives
here, on the consumer side — Hypercode never learns the ontology schema.
"""
import argparse
import json
import os
import subprocess
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

# Envelope knowledge owned by this backend, not by the spec.
API_VERSION = "ontology.specgraph.io/v1alpha1"
KIND = "DomainOntologyPackage"


def emit_ir(ctx):
    binary = os.environ.get(
        "HYPERCODE_BIN", os.path.join(REPO, ".build", "debug", "hypercode"))
    cmd = [binary, "emit", os.path.join(HERE, "examcalc.hc"),
           "--hcs", os.path.join(HERE, "examcalc.hcs"), "--format", "json"]
    for pair in ctx or []:
        cmd += ["--ctx", pair]
    out = subprocess.run(cmd, capture_output=True, encoding="utf-8", cwd=REPO)
    if out.returncode != 0:
        sys.exit(f"emit failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def props(node):
    """Resolved properties of a node as {key: typed value}."""
    return {key: entry["value"] for key, entry in node["properties"].items()}


def children(node, node_type):
    return [c for c in node["children"] if c["type"] == node_type]


def csv(value):
    """Core has no list values — lists travel as comma-joined strings."""
    return [item.strip() for item in str(value).split(",")]


def cardinality(values):
    def bound(v):
        return v if isinstance(v, int) else str(v)
    return {"min": bound(values["card_min"]), "max": bound(values["card_max"])}


SECTIONS = ["Metadata", "Imports", "Classes", "Relations", "Policies",
            "StateMachines", "Compatibility"]


def build(ir):
    package = ir["nodes"][0]
    by_type = {}
    for child in package["children"]:
        if child["type"] in by_type:
            sys.exit(f"malformed package: duplicate '{child['type']}' section")
        by_type[child["type"]] = child
    for section in SECTIONS:
        if section not in by_type:
            sys.exit(f"malformed package: missing '{section}' section")

    meta = props(by_type["Metadata"])
    doc = {
        "apiVersion": API_VERSION,
        "kind": KIND,
        "metadata": {
            "id": meta["package_id"],
            "namespace": meta["namespace"],
            "version": meta["version"],
            "publisher": meta["publisher"],
            "source": meta["source"],
            "approvalStatus": meta["approval_status"],
        },
    }

    imports = []
    for imp in children(by_type["Imports"], "Import"):
        values = props(imp)
        imports.append({"id": values["import_id"],
                        "namespace": values["namespace"],
                        "version": values["version"]})

    classes = {}
    for cls in children(by_type["Classes"], "Class"):
        values = props(cls)
        entry = {"extends": values["extends"]}
        if "implements" in values:
            entry["implements"] = csv(values["implements"])
        if "lifecycle" in values:
            entry["lifecycle"] = values["lifecycle"]
        entry["description"] = values["description"]
        if values.get("central"):
            entry["central"] = True
        fields = {}
        for field in children(cls, "Field"):
            fv = props(field)
            fields[field["id"]] = {
                "type": fv["type"], "required": fv["required"],
                "description": fv["description"],
            }
        if fields:
            entry["fields"] = fields
        classes[cls["id"]] = entry

    relations = {}
    for rel in children(by_type["Relations"], "Relation"):
        values = props(rel)
        targets = csv(values["range"])
        entry = {
            "domain": values["domain"],
            "range": targets[0] if len(targets) == 1 else {"oneOf": targets},
            "cardinality": cardinality(values),
        }
        if "description" in values:
            entry["description"] = values["description"]
        relations[rel["id"]] = entry

    policies = {}
    for pol in children(by_type["Policies"], "Policy"):
        values = props(pol)
        policies[pol["id"]] = {
            "extends": values["extends"],
            "enforceability": values["enforceability"],
            "appliesTo": csv(values["applies_to"]),
            "text": values["text"],
        }

    machines = {}
    for machine in children(by_type["StateMachines"], "Machine"):
        values = props(machine)
        transitions = []
        for tr in children(machine, "Transition"):
            tv = props(tr)
            entry = {"from": tv["from"], "to": tv["to"]}
            if "command" in tv:
                entry["command"] = tv["command"]
            if "event" in tv:
                entry["event"] = tv["event"]
            transitions.append(entry)
        machines[machine["id"]] = {"states": csv(values["states"]),
                                   "transitions": transitions}

    compat = props(by_type["Compatibility"])
    doc["spec"] = {
        "imports": imports,
        "classes": classes,
        "protocols": {},
        "relations": relations,
        "policies": policies,
        "stateMachines": machines,
        "compatibility": {
            "patch": {"allowed": csv(compat["patch_allowed"])},
            "minor": {"allowed": csv(compat["minor_allowed"])},
            "major": {"requires": csv(compat["major_requires"])},
        },
    }
    return doc


def diff_paths(expected, actual, path="$"):
    """Human-readable structural differences (first 20)."""
    out = []
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key in sorted(set(expected) | set(actual)):
            if key not in expected:
                out.append(f"{path}.{key}: unexpected")
            elif key not in actual:
                out.append(f"{path}.{key}: missing")
            else:
                out += diff_paths(expected[key], actual[key], f"{path}.{key}")
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            out.append(f"{path}: length {len(expected)} != {len(actual)}")
        for i, (e, a) in enumerate(zip(expected, actual)):
            out += diff_paths(e, a, f"{path}[{i}]")
    elif expected != actual:
        out.append(f"{path}: {expected!r} != {actual!r}")
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ctx", action="append", default=None,
                        help="key=value resolution context (e.g. stage=approved)")
    parser.add_argument("--out", help="write the generated YAML here")
    parser.add_argument("--check", action="store_true",
                        help="compare semantically against expected/ (CI)")
    args = parser.parse_args()

    doc = build(emit_ir(args.ctx))
    rendered = yaml.safe_dump(doc, sort_keys=False, allow_unicode=True,
                              default_flow_style=False, width=100)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(rendered)
    if args.check:
        expected_path = os.path.join(HERE, "expected",
                                     "domain-ontology-package.yaml")
        with open(expected_path, encoding="utf-8") as handle:
            expected = yaml.safe_load(handle)
        differences = diff_paths(expected, doc)
        if differences:
            print("generated package differs from the Ontology repo original:",
                  file=sys.stderr)
            for line in differences[:20]:
                print(f"  {line}", file=sys.stderr)
            return 1
        print("generated DomainOntologyPackage is semantically identical "
              "to the Ontology repo original (240 lines of YAML)")
        return 0
    if not args.out:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
