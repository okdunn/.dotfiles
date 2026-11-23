#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # zsh -c bodies take $1.. on purpose; check calls helpers by name
# Tests for zsh/.config/zsh/git-guard.zsh: settings an aoe sandbox can write into a repo's
# .git/config or .git/hooks must not run commands when git runs on the host.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
GUARD="$PWD/zsh/.config/zsh/git-guard.zsh"
failed=0
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" GIT_TERMINAL_PROMPT=0
mkdir -p "$HOME"
unset GIT_CONFIG_COUNT GIT_PAGER GIT_EDITOR GIT_SSH_COMMAND

check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
# guarded "<git commands>": run them in $REPO from a zsh that sourced the guard
guarded() { (cd "$REPO" && zsh -f -c 'source "$1"; eval "$2"' _ "$GUARD" "$1") >/dev/null 2>&1; }
ran() { [[ -e "$SANDBOX/ran" ]]; }
fresh() {
  rm -rf "$SANDBOX/repo" "$SANDBOX/ran"
  REPO="$SANDBOX/repo"
  git init -q "$REPO"
  git -C "$REPO" config commit.gpgsign false
  git -C "$REPO" config user.name t
  git -C "$REPO" config user.email t@t
}
plant() { git -C "$REPO" config "$1" "touch $SANDBOX/ran${2:-}"; }

fresh; plant core.fsmonitor '; false'; guarded 'git status'
check fsmonitor-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; printf '#!/bin/sh\ntouch %s\n' "$SANDBOX/ran" >"$REPO/.git/hooks/pre-commit"
chmod +x "$REPO/.git/hooks/pre-commit"; guarded 'git commit -q --allow-empty -m x'
check git-dir-hook-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; mkdir "$REPO/evil"; printf '#!/bin/sh\ntouch %s\n' "$SANDBOX/ran" >"$REPO/evil/pre-commit"
chmod +x "$REPO/evil/pre-commit"; git -C "$REPO" config core.hooksPath evil
guarded 'git commit -q --allow-empty -m x'
check repo-hookspath-ignored bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; plant core.pager '; cat'; guarded 'git commit -q --allow-empty -m x; script -qc "git -p log -1" /dev/null'
check pager-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; plant core.sshCommand; guarded 'git ls-remote ssh://nonexistent.invalid/x'
check ssh-command-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; git -C "$REPO" config credential.helper "!touch $SANDBOX/ran #"
guarded 'printf "protocol=https\nhost=example.com\n\n" | git credential fill'
check credential-helper-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; git -C "$REPO" config credential.https://github.com.helper "!touch $SANDBOX/ran #"
guarded 'printf "protocol=https\nhost=github.com\n\n" | git credential fill'
check github-credential-helper-not-run bash -c '! [[ -e "$1" ]]' _ "$SANDBOX/ran"

fresh; git config --global credential.helper "!touch $SANDBOX/ran #"
guarded 'printf "protocol=https\nhost=example.com\n\n" | git credential fill'
git config --global --unset credential.helper
check global-credential-helper-kept ran

fresh; plant core.editor
check editor-not-repo-value bash -c '[[ $(cd "$1" && zsh -f -c "source \"$2\"; git var GIT_EDITOR") != *ran* ]]' \
  _ "$REPO" "$GUARD"

fresh; printf '#!/bin/sh\ntouch %s\n' "$SANDBOX/ran" >"$REPO/.git/hooks/pre-commit"
chmod +x "$REPO/.git/hooks/pre-commit"; guarded 'githooks commit -q --allow-empty -m x'
check githooks-runs-repo-hooks ran

check keeps-inherited-git-config bash -c 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="*" \
  zsh -f -c "source \"$1\"; git config --get safe.directory >/dev/null"' _ "$GUARD"

check idempotent bash -c '[[ $(zsh -f -c "source \"$1\"; n=\$GIT_CONFIG_COUNT; source \"$1\"; echo \$((GIT_CONFIG_COUNT - n))") == 0 ]]' \
  _ "$GUARD"

exit "$failed"
