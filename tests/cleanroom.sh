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
  bash install.sh "$@" </dev/null

  echo "=== second run (idempotency) ==="
  bash install.sh --stow-only "$@" </dev/null
  if [ -d ~/.dotfiles-backup ]; then
    echo "FAIL: re-run backed up files:"; find ~/.dotfiles-backup -type f; exit 1
  fi

  echo "=== checks ==="
  # Interactive zsh under a pty, the way a real login uses it
  out=$(script -qc "zsh -i -c '\''for t in mise nvim tmux fzf fd bat atuin zoxide eza delta jq btop dust pay-respects claude; do whence -p \$t >/dev/null || echo MISSING:\$t; done; echo ZSH_OK'\''" /dev/null 2>&1 | tr -d "\r")
  echo "$out" | tail -20
  echo "$out" | grep -q "^ZSH_OK" || { echo "FAIL: zsh did not start cleanly"; exit 1; }
  if echo "$out" | grep -qE "MISSING:|Traceback|command not found"; then echo "FAIL: zsh startup problems"; exit 1; fi

  eval "$(~/.local/bin/mise activate bash --shims)"
  tmux -f ~/.tmux.conf new-session -d -s ci && sleep 2
  tmux show -gv status-right | grep -q continuum_save || { echo "FAIL: tmux-continuum autosave not hooked"; exit 1; }
  tmux kill-server
  bat --list-themes | grep -q "Catppuccin Mocha OLED" || { echo "FAIL: bat theme missing"; exit 1; }
  echo "ALL CHECKS PASSED"
' _ "$@"
