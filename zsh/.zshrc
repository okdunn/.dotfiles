# p10k instant prompt — must stay near top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export GOPATH="$HOME/go"
# -U keeps PATH entries unique (nested shells and tmux would otherwise repeat them);
# (N) drops entries whose directory doesn't exist
typeset -U path
path=($HOME/bin(N) $HOME/.local/bin /usr/local/bin $path $GOPATH/bin(N) /snap/bin(N))

# mise must activate before anything that uses tools it installs (atuin, eza, zoxide...)
(( $+commands[mise] )) && eval "$(mise activate zsh)"

# History (atuin handles search; this keeps plain zsh history sane too)
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# Navigation & quality of life
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT INTERACTIVE_COMMENTS

# Autosuggestions in catppuccin overlay0 (dim, readable on black)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"

# Antidote — rebuild bundle only when .zsh_plugins.txt changes
# (the bundle also runs compinit, via belak/zsh-utils, before fzf-tab loads)
source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
if [[ ! -f "$zsh_plugins" || "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" -nt "$zsh_plugins" ]]; then
  antidote bundle < "${ZDOTDIR:-$HOME}/.zsh_plugins.txt" > "$zsh_plugins"
fi
source "$zsh_plugins"

# Catppuccin Mocha file colours for ls, completion lists and eza (eza's own UI colours
# come from ~/.config/eza/theme.yml)
(( $+commands[vivid] )) && export LS_COLORS="$(vivid generate catppuccin-mocha)"
# drop the old ANSI EZA_COLORS that existing shells still export; it would override theme.yml
unset EZA_COLORS

# Completion styling + fzf-tab
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' menu no                            # let fzf-tab take over
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons $realpath'

alias l="eza"
alias la="eza -a"
alias ll="eza -alh"
alias lt="eza --tree --level=2"
alias tree="eza --tree"
alias vim="nvim"
alias vi="nvim"
alias lg="lazygit"
alias lzd="lazydocker"
# Debian ships these under different names
(( $+commands[fd] ))  || { (( $+commands[fdfind] )) && alias fd="fdfind" }
(( $+commands[bat] )) || { (( $+commands[batcat] )) && alias bat="batcat" }

bindkey -v
KEYTIMEOUT=1                          # Esc switches to normal mode instantly (default waits 0.4s)
bindkey -M viins '^?' backward-delete-char  # Backspace past the insert point
bindkey -M viins '^h' backward-delete-char

# Ctrl-F: project picker. A widget, so nothing is typed into the line or saved to history
_tp_widget() {
  zle push-input           # keep anything half-typed; it comes back afterwards
  BUFFER=" tp"             # leading space: HIST_IGNORE_SPACE keeps it out of history
  zle accept-line
}
zle -N _tp_widget
bindkey -M viins '^f' _tp_widget
bindkey -M vicmd '^f' _tp_widget

# fzf: Ctrl-T files, Alt-C dirs (Ctrl-R stays with atuin, which loads after)
if (( $+commands[fzf] )); then
  _fd=${commands[fd]:-${commands[fdfind]}}
  if [[ -n $_fd ]]; then
    export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="$_fd --type d --hidden --follow --exclude .git"
  fi
  unset _fd
  # Catppuccin Mocha accents on true black (OLED)
  export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded \
--color=bg:#000000,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,hl:#f38ba8,hl+:#f38ba8 \
--color=header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,prompt:#cba6f7 \
--color=spinner:#f5e0dc,border:#45475a,label:#cdd6f4,selected-bg:#45475a,gutter:#000000"
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {}'"
  export FZF_ALT_C_OPTS="--preview 'eza -1 --color=always --icons {}'"
  source <(fzf --zsh)
fi

(( $+commands[atuin] )) && eval "$(atuin init zsh)"
# pay-respects: type `f` after a failed command to fix it
(( $+commands[pay-respects] )) && eval "$(pay-respects zsh --alias f)"

# Per-host overrides (untracked)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# zoxide must stay last: it warns if anything runs after its init
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
