# shellcheck shell=bash

run_segment() {
  if command -v top >/dev/null 2>&1; then
    cpu_user=$(top -b -n 1 2>/dev/null | grep "Cpu(s)" | grep -o "[0-9]\+\(\.[0-9]\+\)\? *us\(er\)\?" | awk '{ print $1 }')
    if [ -n "$cpu_user" ]; then
      printf "󰘚 %.0f%%" "${cpu_user}"
      return 0
    fi
  fi
  return 1
}
