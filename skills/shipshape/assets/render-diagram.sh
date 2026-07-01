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

# Slugs are often derived from branch names (arch-feat/x, foo#bar) — reduce to a
# filesystem- and URL-fragment-safe token by construction (collapse any run of other chars).
safe_slug=$(printf '%s' "$slug" | tr -cs 'a-zA-Z0-9-' '_')

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

if command -v glimpse >/dev/null 2>&1 && published=$(glimpse publish "$safe_slug" "$title" "$out"); then
  if [ -n "$pin" ]; then
    glimpse pin "$safe_slug" >/dev/null 2>&1 || echo "warning: pin failed for $safe_slug" >&2
  fi
  # Echo glimpse's own reported line (real URL + port + artifact path) rather than
  # constructing a URL — avoids drift if glimpse runs on a non-default port.
  printf '%s\n' "$published"
else
  dest="./$safe_slug.html"
  cp "$out" "$dest"
  echo "glimpse unavailable — wrote diagram to $dest (open it in a browser)"
fi
