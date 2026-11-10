# p10k instant prompt — must stay near top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export GOPATH="$HOME/go"
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH:$GOPATH/bin:/snap/bin"

# mise must activate before anything that uses tools it installs (atuin, eza, zoxide...)
(( $+commands[mise] )) && eval "$(mise activate zsh)"

# Completion
autoload -Uz compinit && compinit -C

# Antidote — rebuild bundle only when .zsh_plugins.txt changes
source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
if [[ ! -f "$zsh_plugins" || "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" -nt "$zsh_plugins" ]]; then
  antidote bundle < "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" > "$zsh_plugins"
fi
source "$zsh_plugins"

export EZA_COLORS="di=34;1:ln=36:ex=32;1:fi=0:pi=33:so=35:bd=34;46:cd=34;43:or=31;1:mi=31;1"

alias l="eza"
alias ll="eza -alh"
alias tree="eza --tree"
alias vim="nvim"
vi() { (( $# )) && nvim "$@" || nvim }
alias lg="lazygit"
alias lzd="lazydocker"
# Debian ships these under different names
(( $+commands[fd] ))  || { (( $+commands[fdfind] )) && alias fd="fdfind" }
(( $+commands[bat] )) || { (( $+commands[batcat] )) && alias bat="batcat" }

bindkey -v
bindkey -s ^f "tp\n"

(( $+commands[atuin] ))   && eval "$(atuin init zsh)"
# thefuck is unmaintained and crashes on Python >= 3.12; stay silent if broken
(( $+commands[thefuck] )) && eval "$(thefuck --alias 2>/dev/null)"

# Per-host overrides (untracked)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# zoxide must stay last: it warns if anything runs after its init
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
