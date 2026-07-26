# dotfiles

Personal configuration files for various tools.

## Included configs

- Git (`git/`)
- Neovim (`nvim/`)
- Zellij (`zellij/`)
- Zed (`zed/`)
- iTerm2 (`iterm2/`)
- oh-my-posh (`oh-my-posh/`)
- neofetch (`neofetch/`)
- gwq (`gwq/`)
- herdr (`herdr/`)

## Usage

Clone this repository as `~/.config`, or place the directories you need into
the config path each tool expects.

```sh
git clone git@github.com:pineapplebakery/dotfiles.git ~/.config
```

Setup paths and extra steps vary by tool. Check each tool's official
documentation before installing.

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
