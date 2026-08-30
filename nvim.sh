#!/usr/bin/env bash
# Install Neovim from GitHub releases into ~/.local (no sudo).
set -euo pipefail

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./nvim.sh [--dry-run] [-h|--help]

Download the latest Neovim Linux tarball for this machine's architecture
and install it to ~/.local (bin symlink: ~/.local/bin/nvim).

Linux x86_64 and arm64 only. Does not use ~/AppImage or sudo.

  --dry-run   Print planned actions without changing the filesystem
  -h, --help  Show this help
EOF
}

log() { printf '%s\n' "$*"; }
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

os="$(uname -s)"
arch="$(uname -m)"

[[ "$os" == Linux ]] || die "this installer supports Linux only (got ${os})"

case "$arch" in
  x86_64 | amd64) asset_arch=x86_64 ;;
  aarch64 | arm64) asset_arch=arm64 ;;
  *) die "unsupported architecture: ${arch}" ;;
esac

need_cmd curl
need_cmd tar

asset="nvim-linux-${asset_arch}.tar.gz"
url="https://github.com/neovim/neovim/releases/latest/download/${asset}"
prefix="${HOME}/.local"
install_dir="${prefix}/nvim-linux-${asset_arch}"
bin="${prefix}/bin/nvim"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run: no changes will be made"
  log "would  download ${url}"
  log "would  extract  -> ${install_dir}"
  log "would  link     ${bin} -> ${install_dir}/bin/nvim"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "download ${url}"
curl -fL --progress-bar -o "${tmp}/${asset}" "$url"

mkdir -p "${prefix}/bin"
rm -rf "$install_dir"
tar -xzf "${tmp}/${asset}" -C "$prefix"

if [[ ! -x "${install_dir}/bin/nvim" ]]; then
  die "extract failed: ${install_dir}/bin/nvim is missing"
fi

ln -sfn "${install_dir}/bin/nvim" "$bin"
log "link    ${bin} -> ${install_dir}/bin/nvim"

"$bin" --version | head -n 1
log "done."
log "Ensure ${prefix}/bin is on PATH (zsh/conf.d/01-env.zsh already adds it)."
