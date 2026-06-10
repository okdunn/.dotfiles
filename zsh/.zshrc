# p10k instant prompt — must stay near top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.local/scripts:/usr/local/bin:$PATH"

# Antidote — rebuild bundle only when .zsh_plugins.txt changes
source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
if [[ ! -f "$zsh_plugins" || "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" -nt "$zsh_plugins" ]]; then
  antidote bundle < "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" > "$zsh_plugins"
fi
source "$zsh_plugins"

alias ls="eza"
alias l="eza"
alias ll="eza -alh"
alias tree="eza --tree"
alias vim="nvim"
alias lg="lazygit"
alias cat="bat --pager=never"

bindkey -v
bindkey -s ^f "zp\n"

eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
