# dotfiles

Personal configuration files for various tools.

## Included configs

- Git (`git/`)
- Zsh / Oh My Zsh / Powerlevel10k (`zsh/`)
- Neovim (`nvim/`)
- Zellij (`zellij/`)
- Zed (`zed/`)
- iTerm2 (`iterm2/`)
- oh-my-posh (`oh-my-posh/`)
- neofetch (`neofetch/`)
- gwq (`gwq/`)
- herdr (`herdr/`)

## Usage

Clone the repository, then run the installer (symlinks configs and sets up zsh):

```sh
git clone git@github.com:pineapplebakery/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh          # or: ./install.sh --dry-run
```

`install.sh` links package directories into `${XDG_CONFIG_HOME:-$HOME/.config}`,
links `~/.tmux.conf`, and runs `zsh/install.sh`.

### Zsh (Oh My Zsh + Powerlevel10k)

`zsh/install.sh` is idempotent. On a new machine it will:

1. Install [Oh My Zsh](https://ohmyzsh.sh/) if missing
2. Clone [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
3. Clone [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
4. Clone [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
5. Symlink `~/.zshrc` → `zsh/zshrc` and `~/.p10k.zsh` → `zsh/p10k.zsh`

Run only the zsh portion if you prefer:

```sh
./zsh/install.sh
# ./zsh/install.sh --dry-run
```

Requires `git` and `curl`. If `~/.zshrc` or `~/.p10k.zsh` is a real file
(not a symlink), its contents are copied into the repo first (adopt), then
the home path is replaced by a symlink. Drop unwanted local edits with
`git restore zsh/zshrc` (or `zsh/p10k.zsh`) before committing.

After install, open a new terminal or run `exec zsh`.

Tracked files under `zsh/`:

| File | Role |
|------|------|
| `zshrc` | Oh My Zsh config (theme + plugins) |
| `p10k.zsh` | Powerlevel10k prompt settings |
| `install.sh` | Automated bootstrap |
| `conf.d/*.zsh` | Modular fragments sourced at the end of `zshrc` (sorted by name) |

`conf.d/99-local.zsh` is gitignored for machine-local overrides. Create it on each host as needed; it loads last and can override earlier fragments (e.g. `01-env.zsh`).

Plugins and Oh My Zsh itself stay under `~/.oh-my-zsh` (not in this repo).

### Git

Shared settings live in `git/gitconfig` (tracked). Identity stays on the
machine in `~/.gitconfig` (not tracked):

```gitconfig
[user]
    name = Your Name
    email = you@example.com

[include]
    path = ~/.config/git/gitconfig
```

Do not put `user.name` or `user.email` in the tracked file.
`~/.gitconfig` must be a real file, not a symlink to this repository.
