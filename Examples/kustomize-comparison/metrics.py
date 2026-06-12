#!/usr/bin/env python3
"""HC-120: measure the two source trees of the same 3-tenants x 3-envs app.

Counts what humans maintain and review on each side: files, meaningful lines
(non-blank, non-comment), and duplicated lines (a normalized line occurring
in more than one file of the same tree — restated structure, the thing that
drifts). With --check it also validates every hypercode tenant x env target
through the compiled binary, so CI fails when the comparison stops being
honest.

The comparison is about the layer humans edit. Rendering manifests from the
resolved IR is a consumer backend (DOCS/Backends.md) and out of scope here.
"""
import argparse
import os
import subprocess
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

TENANTS = ["acme", "globex", "initech"]
ENVS = ["dev", "staging", "prod"]


def tree_files(root, suffixes):
    out = []
    for dirpath, _, names in os.walk(os.path.join(HERE, root)):
        for name in sorted(names):
            if name.endswith(suffixes):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


def meaningful_lines(path):
    lines = []
    for raw in open(path):
        line = raw.strip()
        if line and not line.startswith("#"):
            lines.append(line)
    return lines


def measure(root, suffixes):
    files = tree_files(root, suffixes)
    per_file = {f: meaningful_lines(f) for f in files}
    total = sum(len(v) for v in per_file.values())
    # A line is "duplicated structure" if it appears in more than one file.
    seen_in = Counter()
    for f, lines in per_file.items():
        for line in set(lines):
            seen_in[line] += 1
    duplicated = sum(
        sum(1 for line in lines if seen_in[line] > 1)
        for lines in per_file.values()
    )
    return {"files": len(files), "lines": total, "duplicated": duplicated}


def check_targets():
    binary = os.environ.get(
        "HYPERCODE_BIN", os.path.join(REPO, ".build", "debug", "hypercode"))
    hc = os.path.join(HERE, "hypercode", "checkout.hc")
    failures = 0
    for tenant in TENANTS:
        for env in ENVS:
            sheet = os.path.join(HERE, "hypercode", "tenants", f"{tenant}.hcs")
            proc = subprocess.run(
                [binary, "validate", hc, "--hcs", sheet, "--ctx", f"env={env}"],
                capture_output=True, text=True)
            if proc.returncode != 0:
                failures += 1
                print(f"FAIL {tenant}/{env}:\n{proc.stdout}{proc.stderr}",
                      file=sys.stderr)
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="also validate all tenant x env targets (CI)")
    args = parser.parse_args()

    kustomize = measure("kustomize", (".yaml",))
    hypercode = measure("hypercode", (".hc", ".hcs"))

    print(f"{len(TENANTS)} tenants x {len(ENVS)} environments "
          f"= {len(TENANTS) * len(ENVS)} build targets\n")
    header = f"{'':24}{'kustomize':>12}{'hypercode':>12}"
    print(header)
    print("-" * len(header))
    for key, label in [("files", "files"), ("lines", "meaningful lines"),
                       ("duplicated", "duplicated lines")]:
        print(f"{label:24}{kustomize[key]:>12}{hypercode[key]:>12}")
    share_k = kustomize["duplicated"] / kustomize["lines"] * 100
    share_h = hypercode["duplicated"] / hypercode["lines"] * 100
    print(f"{'duplication share':24}{share_k:>11.0f}%{share_h:>11.0f}%")

    if args.check:
        failures = check_targets()
        if failures:
            print(f"\n{failures} target(s) failed validation", file=sys.stderr)
            return 1
        print(f"\nall {len(TENANTS) * len(ENVS)} hypercode targets validate "
              "(contracts enforced per context)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
