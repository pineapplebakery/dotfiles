#!/usr/bin/env bash
# Install dotfiles: symlink package dirs into XDG config, and ~/.tmux.conf.
set -euo pipefail

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [-h|--help]

Symlink top-level directories from this repository into
${XDG_CONFIG_HOME:-$HOME/.config}, and link ~/.tmux.conf to ./tmux.conf.

  --dry-run   Print planned actions without changing the filesystem
  -h, --help  Show this help
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $arg (try --help)"
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(realpath "$SCRIPT_DIR")"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

resolve() {
  # Resolve to canonical path if the path exists (follows final symlink).
  # For broken symlinks, realpath fails; caller handles that.
  realpath "$1" 2>/dev/null
}

is_correct_symlink() {
  local dst="$1" src="$2"
  [[ -L "$dst" ]] || return 1
  local dst_res src_res
  dst_res="$(resolve "$dst")" || return 1
  src_res="$(resolve "$src")" || return 1
  [[ "$dst_res" == "$src_res" ]]
}

verify_dir_adopt() {
  # L1: every file/symlink that was under dst before rsync exists under src.
  # Returns 0 on success, 1 on failure (caller prints context).
  local dst="$1" src="$2" list="$3"
  local f rel
  while IFS= read -r -d '' f; do
    rel="${f#"${dst}/"}"
    if [[ ! -e "${src}/${rel}" && ! -L "${src}/${rel}" ]]; then
      warn "missing after rsync: ${rel}"
      return 1
    fi
  done <"$list"
  return 0
}

adopt_directory() {
  local dst="$1" src="$2" name="$3"
  local tmp_list

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "adopt  ${name}  (real directory -> rsync then symlink)"
    return 0
  fi

  tmp_list="$(mktemp)"
  # Record files and symlinks under dst, pruning any .git trees.
  if ! find "$dst" \
    \( -name .git -type d -prune \) -o \
    \( \( -type f -o -type l \) -print0 \) >"$tmp_list"; then
    rm -f "$tmp_list"
    die "find failed for ${name}"
  fi

  if ! rsync -a --exclude '.git' "${dst}/" "${src}/"; then
    rm -f "$tmp_list"
    die "rsync failed for ${name}"
  fi

  if ! verify_dir_adopt "$dst" "$src" "$tmp_list"; then
    rm -f "$tmp_list"
    die "adopt verify failed for ${name}"
  fi
  rm -f "$tmp_list"

  rm -rf "$dst"
  if ! ln -s "$src" "$dst"; then
    printf 'recover: ln -s %q %q\n' "$src" "$dst" >&2
    die "failed to create symlink for ${name} after removing ${dst}"
  fi
  log "adopt  ${name}"
}

link_or_adopt_dir() {
  local name="$1"
  local src="${DOTFILES}/${name}"
  local dst="${CONFIG}/${name}"

  if [[ ! -d "$src" ]]; then
    die "source directory missing: ${src}"
  fi

  if [[ -L "$dst" ]]; then
    if is_correct_symlink "$dst" "$src"; then
      log "skip   ${name}  (already linked)"
      return 0
    fi
    if [[ ! -e "$dst" ]]; then
      die "${dst} is a broken symlink (remove it and re-run)"
    fi
    die "${dst} is a symlink to a different path (expected ${src})"
  fi

  if [[ ! -e "$dst" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "link   ${name}  (missing)"
      return 0
    fi
    ln -s "$src" "$dst" || die "failed to link ${name}"
    log "link   ${name}"
    return 0
  fi

  if [[ -d "$dst" ]]; then
    adopt_directory "$dst" "$src" "$name"
    return 0
  fi

  die "${dst} exists and is not a directory or symlink"
}

adopt_file() {
  local dst="$1" src="$2" label="$3"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "adopt  ${label}  (real file -> copy then symlink)"
    return 0
  fi

  cp -a "$dst" "$src" || die "cp failed for ${label}"
  if [[ ! -f "$src" ]]; then
    die "adopt verify failed: ${src} missing or not a regular file after cp"
  fi

  rm -f "$dst"
  if ! ln -s "$src" "$dst"; then
    printf 'recover: ln -s %q %q\n' "$src" "$dst" >&2
    die "failed to create symlink for ${label} after removing ${dst}"
  fi
  log "adopt  ${label}"
}

link_or_adopt_tmux() {
  local src="${DOTFILES}/tmux.conf"
  local dst="${HOME}/.tmux.conf"
  local label=".tmux.conf"

  if [[ ! -f "$src" && ! -L "$src" ]]; then
    die "source missing: ${src}"
  fi

  if [[ -L "$dst" ]]; then
    if is_correct_symlink "$dst" "$src"; then
      log "skip   ${label}  (already linked)"
      return 0
    fi
    if [[ ! -e "$dst" ]]; then
      die "${dst} is a broken symlink (remove it and re-run)"
    fi
    die "${dst} is a symlink to a different path (expected ${src})"
  fi

  if [[ ! -e "$dst" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "link   ${label}  (missing -> ${src})"
      return 0
    fi
    ln -s "$src" "$dst" || die "failed to link ${label}"
    log "link   ${label}"
    return 0
  fi

  if [[ -f "$dst" ]]; then
    adopt_file "$dst" "$src" "$label"
    return 0
  fi

  die "${dst} exists and is not a regular file or symlink"
}

# --- main ---

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run: no changes will be made"
fi
log "DOTFILES=${DOTFILES}"
log "CONFIG=${CONFIG}"

if [[ ! -d "$CONFIG" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "mkdir  ${CONFIG}"
  else
    mkdir -p "$CONFIG"
  fi
fi

if [[ -e "${CONFIG}/.git" ]]; then
  warn "${CONFIG}/.git exists (old clone-as-config layout?)."
  warn "Canonical repo is ${DOTFILES}; consider removing ${CONFIG}/.git after install."
fi

# Phase 1: top-level directories only (skip .git)
shopt -s nullglob
for path in "${DOTFILES}"/*; do
  [[ -d "$path" ]] || continue
  name="$(basename "$path")"
  [[ "$name" == .git ]] && continue
  link_or_adopt_dir "$name"
done
shopt -u nullglob

# Phase 2: home .tmux.conf -> repo tmux.conf
link_or_adopt_tmux

# Phase 3: Oh My Zsh + Powerlevel10k + plugins + ~/.zshrc / ~/.p10k.zsh
zsh_install="${DOTFILES}/zsh/install.sh"
if [[ -x "$zsh_install" ]]; then
  log "--- zsh ---"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    "$zsh_install" --dry-run
  else
    "$zsh_install"
  fi
elif [[ -f "$zsh_install" ]]; then
  warn "zsh/install.sh is not executable; run: chmod +x zsh/install.sh"
else
  warn "zsh/install.sh not found; skipping zsh setup"
fi

log "done."
