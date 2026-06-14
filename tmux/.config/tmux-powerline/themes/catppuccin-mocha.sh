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
  TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$''
  sep_sharp_right=$''
  sep_sharp_left=$''
else
  TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=$'◀'
  TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$'❮'
  TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=$'▶'
  TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$'❯'
  sep_sharp_right=$'▶'
  sep_sharp_left=$'◀'
fi

TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR:-$base}
TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR:-$text}
# shellcheck disable=SC2034
TMUX_POWERLINE_SEG_AIR_COLOR=$(tp_air_color)

TMUX_POWERLINE_SEPARATOR_LEFT_THIN=$'\xee\x82\xbb'
TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR=$'\xee\x82\xbc'
win_icon=$'\xee\xad\xbf'
TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_LEFT_BOLD}

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_CURRENT" ]; then
  TMUX_POWERLINE_WINDOW_STATUS_CURRENT=(
    "#[fg=$base,bg=$mauve]${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR}"
    "#[fg=$base,bg=$mauve] ${win_icon} #[fg=$surface0]${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}#[fg=$base] #W "
    "#[fg=$mauve,bg=$base]${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR}"
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
    "#[fg=$base,bg=$surface0]${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR}"
    "#[fg=$overlay1,bg=$surface0] #I #[fg=$surface1]${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}#[fg=$overlay1] #W "
    "#[fg=$surface0,bg=$base]${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR}"
  )
fi

TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
  "whoami_icon $lavender $base"
  "tmux_session_info $mauve $base"
)

# shellcheck disable=SC1143,SC2128
TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
  "cpu_icon $surface0 $overlay1"
  "mem_used $surface0 $overlay1"
  "disk_icon $surface0 $overlay1"
  "time $mauve $base"
)
