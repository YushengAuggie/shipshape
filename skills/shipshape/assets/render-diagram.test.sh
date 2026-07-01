#!/usr/bin/env sh
# Tests for render-diagram.sh. Run: sh render-diagram.test.sh
# Exercises the deterministic render logic via the no-glimpse (file) path.
set -eu

DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
SCRIPT="$DIR/render-diagram.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

check() { # <name> <test-expr>
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fails=$((fails + 1)); fi
}

# Mermaid body deliberately contains __TITLE__ to prove it is NOT substituted.
printf 'flowchart LR\n  A[__TITLE__ marker] --> B\n' > "$tmp/d.mmd"

# Run in degrade mode (glimpse hidden from PATH) from tmp, so ./<slug>.html lands in tmp.
run() { ( cd "$tmp" && PATH=/usr/bin:/bin sh "$SCRIPT" "$@" ); }

# 1. Slug with slash and '#' is reduced to a filesystem/URL-safe token.
run "arch-feat/x#y" "Title" "$tmp/d.mmd" >/dev/null 2>&1
check "slug sanitized to arch-feat_x_y" '[ -f "$tmp/arch-feat_x_y.html" ]'

# 2. Title containing & and < is preserved literally (no gsub/entity mangling).
run "t-amp" "Auth & Billing <v2>" "$tmp/d.mmd" >/dev/null 2>&1
check "title '& <' preserved" 'grep -q "Auth & Billing <v2>" "$tmp/t-amp.html"'

# 3. __TITLE__ appearing in the mermaid BODY must survive (not replaced by the title).
check "__TITLE__ in body preserved" 'grep -q "__TITLE__ marker" "$tmp/t-amp.html"'
check "title did not leak into body node" '! grep -q "Auth & Billing <v2> marker" "$tmp/t-amp.html"'

# 4. Missing mermaid file exits nonzero.
if run "x" "T" "$tmp/nope.mmd" >/dev/null 2>&1; then
  check "missing mmd exits nonzero" 'false'
else
  check "missing mmd exits nonzero" 'true'
fi

# 5. No-glimpse path writes ./<slug>.html (graceful degrade).
check "degrade path wrote local html" '[ -f "$tmp/t-amp.html" ]'

if [ "$fails" -eq 0 ]; then echo "All tests passed."; else echo "$fails test(s) failed."; exit 1; fi
