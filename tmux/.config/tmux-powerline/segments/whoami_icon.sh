# shellcheck shell=bash

run_segment() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      ubuntu)  icon=$'' ;;
      debian)  icon=$'' ;;
      *)       icon=$'' ;;
    esac
  else
    icon=$''
  fi
  printf '%s %s@%s' "$icon" "$(whoami)" "$(hostname -s)"
  return 0
}
