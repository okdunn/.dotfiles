# shellcheck shell=bash

run_segment() {
  local fs="${TMUX_POWERLINE_SEG_DISK_USAGE_FILESYSTEM:-/}"
  local pct
  pct=$(df "$fs" 2>/dev/null | awk 'NR==2{print $5}')
  if [ -n "$pct" ]; then
    echo "󰋊 ${pct}"
    return 0
  fi
  return 1
}
