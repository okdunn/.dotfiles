#!/usr/bin/env bash
# Generate an ed25519 SSH key. ssh-keygen prompts for the passphrase itself,
# so it never appears in the process list.
set -euo pipefail

key="$HOME/.ssh/id_ed25519"

if [[ -e "$key" ]]; then
  echo "Error: $key already exists; not overwriting." >&2
  exit 1
fi

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
read -rp "Enter email for SSH key: " email

ssh-keygen -t ed25519 -C "$email" -f "$key"

echo
echo "New SSH public key:"
cat "$key.pub"
