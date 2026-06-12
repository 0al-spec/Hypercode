#!/usr/bin/env bash
# HC-124 demo: regenerate stale modules from the resolved graph via Claude.
#
# check.py decides WHAT to regenerate (node-hash comparison scopes the work);
# this script asks Claude to regenerate ONLY those modules, feeding it the
# IR subtree of the module's node. Requires the `claude` CLI on PATH.
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
BIN="${HYPERCODE_BIN:-$REPO/.build/debug/hypercode}"
HC="${1:-$REPO/Examples/service.hc}"
HCS="${2:-$REPO/Examples/service.hcs}"
CTX="${CTX:-env=production}"

IR="$(mktemp)"
"$BIN" emit "$HC" --hcs "$HCS" --ctx "$CTX" --format json > "$IR"

STALE="$(python3 check.py --hc "$HC" --hcs "$HCS" --ctx "$CTX" --list-stale || true)"
if [ -z "$STALE" ]; then
    echo "all modules fresh — nothing to regenerate"
    exit 0
fi

command -v claude >/dev/null || {
    echo "stale modules:" "$STALE"
    echo "claude CLI not found — install Claude Code to regenerate automatically"
    exit 1
}

for MODULE in $STALE; do
    NODE_PATH="$(grep -m1 '^# node: ' "generated/$MODULE" | cut -d' ' -f3)"
    NODE_JSON="$(python3 - "$IR" "$NODE_PATH" <<'PY'
import json, sys
ir = json.load(open(sys.argv[1]))
def find(nodes, path):
    for n in nodes:
        p = path + "/" + n["type"]
        if p == sys.argv[2]: return n
        if (r := find(n["children"], p)): return r
find_result = find(ir["nodes"], "")
print(json.dumps(find_result, indent=2))
PY
)"
    echo "regenerating $MODULE from node $NODE_PATH …"
    claude -p "Regenerate the Python module below from this Hypercode IR v2 node.

Conventions (must match the existing modules in this directory exactly):
- header comments: '# GENERATED…', '# node: $NODE_PATH', '# hash: <the node's hash field>', '# context: $CTX'
- a CONFIG dict literal with one entry per resolved property used by the module,
  each with a provenance comment '# <winner.selector> @ <winner.file>:<winner.line>'
- keep the same class/function structure as the current file; only values,
  hash and provenance comments change
- output ONLY the Python source, no markdown fences

Current file:
$(cat "generated/$MODULE")

IR node (the source of truth):
$NODE_JSON" > "generated/$MODULE.new" && mv "generated/$MODULE.new" "generated/$MODULE"
done

python3 check.py --hc "$HC" --hcs "$HCS" --ctx "$CTX"
