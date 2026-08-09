# Shared environment / PATH tweaks (tracked).
# Machine-local secrets and overrides go in 99-local.zsh (gitignored).

export PATH=$HOME/.local/bin:$HOME/go/bin:$PATH
export EDITOR=nvim

alias vim='nvim'
alias ls='eza --icons --git'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

peco-select-history() {
    BUFFER=$(history -n 1 | tac | peco)
    CURSOR=$#BUFFER
    zle clear-screen
}
zle -N peco-select-history
bindkey '^R' peco-select-history

eval "$(zoxide init zsh)"
