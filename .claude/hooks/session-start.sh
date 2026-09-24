#!/bin/bash
# SessionStart hook for Claude Code on the web. A fresh cloud container has no
# Godot, so install the engine this project targets, the Python packages the
# asset generators and linter need, and build the import cache so the game and
# its headless tests run straight away:
#   godot --headless --path . res://tests/SmokeTest.tscn
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.1"  # keep in step with the version named in README.md
GODOT_DIR="/opt/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Installing Godot ${GODOT_VERSION}..." >&2
  mkdir -p "$GODOT_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/godot.zip" "$GODOT_URL"
  python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/godot.zip" "$GODOT_DIR"
  chmod +x "$GODOT_BIN"
  rm -rf "$tmp"
fi
ln -sf "$GODOT_BIN" /usr/local/bin/godot

# Pillow/numpy: tools/gen_sprites.py and tools/gen_audio.py. gdtoolkit: gdlint,
# which parses a script on its own (Godot's --check-only cannot see autoloads).
python3 -m pip install --quiet --root-user-action=ignore pillow numpy gdtoolkit

# Build .godot/ (imported textures, fonts, class cache) so scenes load on first run.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
godot --headless --path . --import >/dev/null 2>&1
echo "Godot $(godot --version) ready." >&2
