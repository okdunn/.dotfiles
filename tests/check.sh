#!/usr/bin/env bash
# Local CI: lint everything in the repo. Not enforced anywhere — run it by hand
# (or `dot check`) before pushing.
#
#   tests/check.sh              shellcheck + zsh/bash syntax + stylua
#   tests/check.sh --cleanroom  also run the full Docker install test on Ubuntu 24.04 and Debian 12
#
# Shell scripts are found by shebang (or a `# shellcheck shell=` first line), so new scripts are covered without editing this file.
set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
failed=()
step() { echo -e "${GREEN}==>${NC} $1"; }
fail() { echo -e "${RED}==> FAIL:${NC} $1"; failed+=("$1"); }
skip() { echo -e "${YELLOW}==> SKIP:${NC} $1"; }

# Run a tool from PATH, or through mise if it isn't installed (fetched on first use)
tool() {
  local name="$1"
  shift
  # --version rather than command -v: a mise shim with no version set exists but can't run
  if "$name" --version &>/dev/null; then
    "$name" "$@"
  elif command -v mise &>/dev/null; then
    mise exec "$name@latest" -- "$name" "$@"
  else
    return 127
  fi
}

bash_files=() zsh_files=()
while IFS= read -r -d '' f; do
  shebang=$(head -n1 "$f")
  case "$shebang" in
    '#!'*zsh*) zsh_files+=("$f") ;;
    '#!'*sh* | '# shellcheck shell='*) bash_files+=("$f") ;; # shebang, or a sourced file's directive
  esac
done < <(git ls-files -z --cached --others --exclude-standard)
zsh_files+=(zsh/.zshrc)

step "shellcheck (${#bash_files[@]} files)"
tool shellcheck -x "${bash_files[@]}" || fail shellcheck

step "bash -n"
for f in "${bash_files[@]}"; do bash -n "$f" || fail "bash -n $f"; done

step "zsh -n (${#zsh_files[@]} files)"
if command -v zsh &>/dev/null; then
  for f in "${zsh_files[@]}"; do zsh -n "$f" || fail "zsh -n $f"; done
else
  skip "zsh not installed"
fi

step "stylua --check"
# nvim only: wezterm.lua uses tabs and has no stylua config of its own
tool stylua --check nvim/.config/nvim || fail stylua

if [[ "${1:-}" == "--cleanroom" ]]; then
  for image in ubuntu:24.04 debian:12; do
    step "clean-room install on $image"
    docker run --rm -v "$PWD:/src:ro" -e GITHUB_TOKEN "$image" bash /src/tests/cleanroom.sh ||
      fail "cleanroom $image"
  done
fi

echo
if ((${#failed[@]})); then
  echo -e "${RED}Failed:${NC} ${failed[*]}"
  exit 1
fi
echo -e "${GREEN}All checks passed${NC}"
