#!/usr/bin/env bash

read -rp "Enter email for SSH key: " email

read -rsp "Enter passphrase (leave empty for none): " passphrase
echo
read -rsp "Confirm passphrase: " passphrase_confirm
echo

if [[ "$passphrase" != "$passphrase_confirm" ]]; then
  echo "Error: Passphrases do not match!"
  exit 1
fi

if [[ -n "$passphrase" ]]; then
  ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N "$passphrase"
else
  ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
fi

eval "$(ssh-agent -s)"

ssh-add ~/.ssh/id_ed25519

echo "New SSH public key:"
cat ~/.ssh/id_ed25519.pub