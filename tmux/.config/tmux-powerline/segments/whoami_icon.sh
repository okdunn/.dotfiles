# shellcheck shell=bash

run_segment() {
  printf ' %s@%s' "$(whoami)" "$(hostname -s)"
  return 0
}
