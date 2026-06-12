# shellcheck shell=bash

base="#1e1e2e"
surface0="#313244"
surface1="#45475a"
overlay1="#7f849c"
text="#cdd6f4"
lavender="#b4befe"
blue="#89b4fa"
sapphire="#74c7ec"
teal="#94e2d5"
green="#a6e3a1"
yellow="#f9e2af"
peach="#fab387"
maroon="#eba0ac"
mauve="#cba6f7"

if tp_patched_font_in_use; then
  TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=$''
  TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$''
  TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=$''
  TMUX_POWERLINE_SEPARATOR_RIGHT_THIN=$''
  sep_sharp_right=$''
  sep_sharp_left=$''
else
  TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=$'◀'
  TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$'❮'
  TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=$'▶'
  TMUX_POWERLINE_SEPARATOR_RIGHT_THIN=$'❯'
  sep_sharp_right=$'▶'
  sep_sharp_left=$'◀'
fi

TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR:-$base}
TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR:-$text}
# shellcheck disable=SC2034
TMUX_POWERLINE_SEG_AIR_COLOR=$(tp_air_color)

TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}
TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_LEFT_BOLD}

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_CURRENT" ]; then
  TMUX_POWERLINE_WINDOW_STATUS_CURRENT=(
    "#{?#{==:#{window_index},0},,#[fg=$base,bg=$mauve]${TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}}"
    "#[fg=$base,bg=$mauve] #W "
    "#[fg=$mauve,bg=$base]${TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}"
  )
fi

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_STYLE" ]; then
  TMUX_POWERLINE_WINDOW_STATUS_STYLE=(
    "bg=$base,fg=$overlay1"
  )
fi

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_FORMAT" ]; then
  TMUX_POWERLINE_WINDOW_STATUS_FORMAT=(
    "#{?#{==:#{window_index},0},,#[fg=$base,bg=$surface1]${TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}}"
    "#[fg=$overlay1,bg=$surface1] #W "
    "#[fg=$surface1,bg=$base]${TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}"
  )
fi

TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=()

# shellcheck disable=SC1143,SC2128
if [ -z "$TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS" ]; then
  TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
    "ifstat_sys $teal $base"
    "cpu_icon $peach $base"
    "mem_used $peach $base"
    "disk_icon $peach $base"
    "whoami_icon $lavender $base"
    "time $mauve $base"
  )
fi
