#!/usr/bin/env sh
# shipshape installer: installs the skill + ensures no-mistakes; glimpse optional.
set -eu

REPO_RAW="https://raw.githubusercontent.com/YushengAuggie/shipshape/main"
# Resolve skills dir (Claude Code default; override with SHIPSHAPE_SKILLS_DIR for other agents)
SKILLS_DIR=${SHIPSHAPE_SKILLS_DIR:-"$HOME/.claude/skills"}
mkdir -p "$SKILLS_DIR/shipshape"

echo "→ Installing shipshape skill into $SKILLS_DIR/shipshape"
if [ -d "./skills/shipshape" ]; then
  cp -R ./skills/shipshape/. "$SKILLS_DIR/shipshape/"      # local clone install
else
  # remote install: fetch the skill files
  for f in SKILL.md assets/diagram-template.html assets/render-diagram.sh assets/review-lenses.md; do
    mkdir -p "$SKILLS_DIR/shipshape/$(dirname "$f")"
    curl -fsSL "$REPO_RAW/skills/shipshape/$f" -o "$SKILLS_DIR/shipshape/$f"
  done
fi
chmod +x "$SKILLS_DIR/shipshape/assets/render-diagram.sh"

echo "→ Checking required dependency: no-mistakes"
if ! command -v no-mistakes >/dev/null 2>&1; then
  echo "  no-mistakes not found — installing it"
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
else
  echo "  no-mistakes present: $(no-mistakes --version 2>/dev/null | head -1)"
fi

echo "→ Optional: glimpse (live canvas)"
if command -v glimpse >/dev/null 2>&1; then
  echo "  glimpse present — diagrams will render live"
else
  echo "  glimpse not found — diagrams will be written to files instead."
  echo "  To enable the live canvas later: https://github.com/YushengAuggie/glimpse"
fi

cat <<'EOF'

✓ shipshape installed.
  Next: in a repo, run `no-mistakes init` once, then invoke /shipshape on a change.
EOF
