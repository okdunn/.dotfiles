#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

case "$OS" in
  Darwin) bash "$DIR/install/macos.sh" "$@" ;;
  Linux)  bash "$DIR/install/debian.sh" "$@" ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac
