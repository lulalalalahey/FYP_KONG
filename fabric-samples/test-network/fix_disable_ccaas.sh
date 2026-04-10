#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

files=(
  "$ROOT/compose/compose-test-net.yaml"
  "$ROOT/compose/compose-bft-test-net.yaml"
  "$ROOT/compose/docker/peercfg/core.yaml"
  "$ROOT/compose/podman/peercfg/core.yaml"
)

echo "==> [1/4] Pre-check"
for f in "${files[@]}"; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  SKIP (not found): $f"
  fi
done

echo
echo "==> [2/4] Backup"
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  cp -a "$f" "$f.bak.$TS"
  echo "  Backup: $f.bak.$TS"
done

echo
echo "==> [3/4] Patch compose yaml (remove CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG lines)"
for f in "$ROOT/compose/compose-test-net.yaml" "$ROOT/compose/compose-bft-test-net.yaml"; do
  [[ -f "$f" ]] || continue
  # delete any env line containing CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG
  sed -i '/^[[:space:]]*-[[:space:]]*CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG=.*/d' "$f"
  echo "  Patched: $f"
done

echo
echo "==> [3/4] Patch core.yaml (remove externalBuilders block)"
for f in "$ROOT/compose/docker/peercfg/core.yaml" "$ROOT/compose/podman/peercfg/core.yaml"; do
  [[ -f "$f" ]] || continue

  # Use awk to drop the entire 'externalBuilders:' block under 'chaincode:' section.
  # Logic: when we see a line with 'externalBuilders:' capture its indent, then skip
  # all subsequent lines with greater indent until indent decreases.
  awk '
  function indentLen(s,   t) { t=s; sub(/[^ ].*$/, "", t); return length(t); }
  BEGIN { skipping=0; skipIndent=-1; }
  {
    if (!skipping) {
      if ($0 ~ /^[[:space:]]*externalBuilders:[[:space:]]*$/) {
        skipping=1;
        skipIndent=indentLen($0);
        next;
      }
      print $0;
      next;
    } else {
      # while skipping: stop when indent <= skipIndent AND line is not empty
      if ($0 ~ /^[[:space:]]*$/) { next; }
      if (indentLen($0) <= skipIndent) {
        skipping=0;
        print $0;
      } else {
        next;
      }
    }
  }' "$f" > "$f.tmp.$TS"

  mv "$f.tmp.$TS" "$f"
  echo "  Patched: $f"
done

echo
echo "==> [4/4] Show diffs (first 200 lines each)"
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  bak="$f.bak.$TS"
  [[ -f "$bak" ]] || continue
  echo "------ DIFF: $f ------"
  diff -u "$bak" "$f" | sed -n '1,200p' || true
  echo
done

echo "✅ Done. Now recreate network (down/up) and redeploy chaincode."
echo "   Example:"
echo "   cd ../shard-experiment && ./run_experiment.sh 2 4"
