#!/usr/bin/env bash
# Install Oh My Zsh, Powerlevel10k, popular plugins, and link zsh configs.
set -euo pipefail

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./zsh/install.sh [--dry-run] [-h|--help]

Installs (if missing):
  - Oh My Zsh          (~/.oh-my-zsh)
  - Powerlevel10k      ($ZSH_CUSTOM/themes/powerlevel10k)
  - zsh-autosuggestions
  - zsh-syntax-highlighting

Then links home configs:
  ~/.zshrc    -> <this-dir>/zshrc
  ~/.p10k.zsh -> <this-dir>/p10k.zsh

If a real file already exists at the home path, its contents are copied
into the repo (adopt), then replaced by a symlink. Discard with git restore
if you do not want the local changes.

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
ZSH_HOME="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_HOME/custom}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

resolve() {
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

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would  $*"
    return 0
  fi
  "$@"
}

# Clone repo if missing. If present as a git repo, leave it (idempotent).
# Args: url dest [extra git clone args...]
ensure_git_clone() {
  local url="$1" dest="$2"
  shift 2

  if [[ -d "$dest/.git" ]]; then
    log "skip   $(basename "$dest")  (already cloned)"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    die "${dest} exists but is not a git clone; remove it and re-run"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "clone  ${url} -> ${dest}"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  git clone "$@" "$url" "$dest"
  log "clone  $(basename "$dest")"
}

# Adopt a real home file into the repo, then symlink home -> repo.
# Matches install.sh adopt_file: local content wins; undo with git restore.
adopt_home_file() {
  local dst="$1" src="$2" label="$3"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "adopt  ${label}  (real file -> copy into repo then symlink)"
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

link_home_file() {
  local src="$1" dst="$2" label="$3"

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
    adopt_home_file "$dst" "$src" "$label"
    return 0
  fi

  die "${dst} exists and is not a regular file or symlink"
}

install_oh_my_zsh() {
  if [[ -d "$ZSH_HOME/oh-my-zsh.sh" ]] || [[ -f "$ZSH_HOME/oh-my-zsh.sh" ]]; then
    log "skip   oh-my-zsh  (already installed at ${ZSH_HOME})"
    return 0
  fi

  if [[ -e "$ZSH_HOME" ]]; then
    die "${ZSH_HOME} exists but does not look like Oh My Zsh"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "install oh-my-zsh -> ${ZSH_HOME}"
    return 0
  fi

  # Unattended: keep any existing ~/.zshrc, do not chsh, do not enter zsh.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log "install oh-my-zsh"
}

# --- main ---

need_cmd git
need_cmd curl

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run: no changes will be made"
fi

log "SCRIPT_DIR=${SCRIPT_DIR}"
log "ZSH_HOME=${ZSH_HOME}"
log "ZSH_CUSTOM=${ZSH_CUSTOM}"

install_oh_my_zsh

ensure_git_clone \
  https://github.com/romkatv/powerlevel10k.git \
  "${ZSH_CUSTOM}/themes/powerlevel10k" \
  --depth=1

ensure_git_clone \
  https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

ensure_git_clone \
  https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

link_home_file "${SCRIPT_DIR}/zshrc" "${HOME}/.zshrc" ".zshrc"
link_home_file "${SCRIPT_DIR}/p10k.zsh" "${HOME}/.p10k.zsh" ".p10k.zsh"

log "done."
log "Open a new terminal, or run: exec zsh"
log "If the prompt wizard runs, answer it or use the linked ~/.p10k.zsh as-is."
