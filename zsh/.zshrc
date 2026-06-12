# p10k instant prompt — must stay near top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Antidote — rebuild bundle only when .zsh_plugins.txt changes
source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
if [[ ! -f "$zsh_plugins" || "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" -nt "$zsh_plugins" ]]; then
  antidote bundle < "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" > "$zsh_plugins"
fi
source "$zsh_plugins"

export EZA_COLORS="di=34;1:ln=36:ex=32;1:fi=0:pi=33:so=35:bd=34;46:cd=34;43:or=31;1:mi=31;1"

alias ls="eza"
alias l="eza"
alias ll="eza -alh"
alias tree="eza --tree"
alias vim="nvim"
vi() { (( $# )) && nvim "$@" || nvim }
alias lg="lazygit"
alias lzd="lazydocker"
alias cat="bat --pager=never"

bindkey -v
bindkey -s ^f "zp\n"

. "$HOME/.atuin/bin/env"

eval "$(zoxide init zsh --cmd cd)"
eval "$(atuin init zsh)"
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
