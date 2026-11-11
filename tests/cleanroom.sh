#!/usr/bin/env bash
# Clean-room install test. Runs inside a fresh Debian/Ubuntu container as root,
# with the repo mounted read-only at /src:
#
#   docker run --rm -v "$PWD:/src:ro" -e GITHUB_TOKEN ubuntu:24.04 bash /src/tests/cleanroom.sh
#
# Extra args are passed to install.sh (e.g. --langs). GITHUB_TOKEN is optional but
# avoids GitHub API rate limits when mise downloads tools.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sudo git curl ca-certificates >/dev/null

useradd -m -s /bin/bash tester
echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester
cp -a /src /home/tester/.dotfiles
chown -R tester: /home/tester/.dotfiles

sudo -u tester -H env GITHUB_TOKEN="${GITHUB_TOKEN:-}" bash -euo pipefail -c '
  cd ~/.dotfiles
  # Pre-existing Claude Code settings must survive the merge
  mkdir -p ~/.claude && echo "{\"theme\": \"light\"}" > ~/.claude/settings.json
  # Identity is normally prompted for; preset it so the non-interactive run is complete
  git config --file ~/.gitconfig.local user.name "CI Tester"
  git config --file ~/.gitconfig.local user.email "ci@example.com"
  bash install.sh "$@" </dev/null

  echo "=== second run (idempotency) ==="
  bash install.sh --stow-only </dev/null  # no extras: must reuse the saved profile
  if [ -d ~/.dotfiles-backup ]; then
    echo "FAIL: re-run backed up files:"; find ~/.dotfiles-backup -type f; exit 1
  fi

  echo "=== saved profile ==="
  # The second run above passed no extras, so it must have reused the first runs flags
  for flag in "$@"; do
    case "$flag" in --desktop | --langs) grep -qx -- "$flag" ~/.config/dotfiles/profile || { echo "FAIL: $flag not saved to profile"; exit 1; } ;; esac
  done
  case " $* " in *" --langs "*) [ -L ~/.config/mise/conf.d/langs.toml ] || { echo "FAIL: mise-langs unlinked by flagless rerun"; exit 1; } ;; esac

  echo "=== checks ==="
  eval "$(~/.local/bin/mise activate bash --shims)"
  jq -e ".theme == \"light\"" ~/.claude/settings.json >/dev/null \
    || { echo "FAIL: pre-existing Claude setting lost in merge"; cat ~/.claude/settings.json; exit 1; }
  # dot doctor checks the running tmux server; start one so the plugin check runs
  tmux -f ~/.tmux.conf new-session -d -s ci && sleep 2
  ~/bin/dot doctor
  tmux kill-server
  echo "ALL CHECKS PASSED"
' _ "$@"
