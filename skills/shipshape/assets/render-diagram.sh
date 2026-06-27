#!/usr/bin/env sh
# Usage: render-diagram.sh <slug> <title> <mermaid-file> [--pin]
# Fills the template with the mermaid source + title, then:
#   - if glimpse is installed AND `glimpse publish` succeeds: publishes (pins with --pin),
#     prints the canvas URL
#   - otherwise (no glimpse, or canvas unreachable): writes ./<slug>.html and prints the path
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
TEMPLATE="$SCRIPT_DIR/diagram-template.html"

slug=${1:?slug required}
title=${2:?title required}
mmd=${3:?mermaid file required}

# --pin may appear in any position after the required args
pin=""
case " $* " in *" --pin "*) pin=1 ;; esac

# Slugs are often derived from branch names (arch-feat/x) — sanitize for filesystem + URL use.
safe_slug=$(printf '%s' "$slug" | tr '/ ' '__')

[ -f "$TEMPLATE" ] || { echo "template missing: $TEMPLATE" >&2; exit 1; }
[ -f "$mmd" ] || { echo "mermaid file missing: $mmd" >&2; exit 1; }

out=$(mktemp -t shipshape-diagram.XXXXXX)
trap 'rm -f "$out"' EXIT

# Fill the template. The title is replaced literally via ENVIRON + index/substr (no regex or
# gsub replacement specials, so '&' and '\' in the title are safe); the mermaid body is streamed
# in from the file (multiline-safe, no escaping).
TITLE_ENV="$title" awk -v mfile="$mmd" '
  {
    line = $0
    if (line ~ /__MERMAID__/) { while ((getline m < mfile) > 0) print m; next }
    t = ENVIRON["TITLE_ENV"]; rest = line; out = ""
    p = index(rest, "__TITLE__")
    while (p > 0) {
      out = out substr(rest, 1, p - 1) t
      rest = substr(rest, p + 9)        # 9 = length("__TITLE__")
      p = index(rest, "__TITLE__")
    }
    print out rest
  }
' "$TEMPLATE" > "$out"

if command -v glimpse >/dev/null 2>&1 && glimpse publish "$safe_slug" "$title" "$out"; then
  if [ -n "$pin" ]; then
    glimpse pin "$safe_slug" >/dev/null 2>&1 || echo "warning: pin failed for $safe_slug" >&2
  fi
  echo "canvas: http://127.0.0.1:4321/#$safe_slug"
else
  dest="./$safe_slug.html"
  cp "$out" "$dest"
  echo "glimpse unavailable — wrote diagram to $dest (open it in a browser)"
fi
