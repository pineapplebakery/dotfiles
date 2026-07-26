#!/usr/bin/env bash
# Reinstall Herdr plugins for this machine.
#
# plugins.json is machine-local (absolute paths) — do not commit it.
# Commit this script (and config.toml / plugins/config/) instead.
#
# Usage:
#   ./install-plugins.sh
#   ./install-plugins.sh --force   # reinstall even if already present
set -euo pipefail

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

if ! command -v "$HERDR_BIN" >/dev/null 2>&1; then
  echo "error: herdr not found on PATH (set HERDR_BIN_PATH to override)" >&2
  exit 1
fi

# owner/repo — edit this list when you add or remove plugins
PLUGINS=(
  "persiyanov/herdr-reviewr"
  "edmundmiller/herdr-plugin-hunk"
  "smarzban/herdr-file-viewer"
)

# True if herdr already has this github owner/repo (or matching plugin_id).
plugin_installed() {
  local spec="$1"
  local owner="${spec%%/*}"
  local repo="${spec#*/}"
  HERDR_BIN="$HERDR_BIN" OWNER="$owner" REPO="$repo" python3 - <<'PY'
import json, os, subprocess, sys

herdr = os.environ["HERDR_BIN"]
owner = os.environ["OWNER"]
repo = os.environ["REPO"]
try:
    raw = subprocess.check_output([herdr, "plugin", "list", "--json"], text=True)
    data = json.loads(raw)
except Exception:
    sys.exit(1)

plugins = data.get("result", {}).get("plugins") or []
want = f"{owner}/{repo}".lower()
for p in plugins:
    src = p.get("source") or {}
    if src.get("kind") == "github":
        got = f"{src.get('owner', '')}/{src.get('repo', '')}".lower()
        if got == want:
            sys.exit(0)
    pid = (p.get("plugin_id") or "").lower()
    if pid in {repo.lower(), f"{owner}.{repo}".lower().replace("-", ".")}:
        sys.exit(0)
sys.exit(1)
PY
}

echo "Using: $($HERDR_BIN --version 2>/dev/null || echo "$HERDR_BIN")"
echo

for spec in "${PLUGINS[@]}"; do
  if [[ "$FORCE" -eq 0 ]] && plugin_installed "$spec"; then
    echo "skip     $spec  (already installed; pass --force to reinstall)"
    continue
  fi
  echo "install  $spec"
  # Non-interactive installs require --yes when stdin is not a TTY.
  "$HERDR_BIN" plugin install "$spec" --yes
done

echo
echo "done. git-friendly pieces:"
echo "  config.toml"
echo "  plugins/config/<plugin_id>/"
echo "  install-plugins.sh"
echo
"$HERDR_BIN" plugin list
