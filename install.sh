#!/usr/bin/env bash
# Usage: install.sh [--stow-only] [--desktop]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -r /etc/os-release ]]; then
  echo "Unsupported OS: /etc/os-release not found (Debian/Ubuntu only)" >&2
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "* | *" ubuntu "*) ;;
  *) echo "Unsupported distro: ${PRETTY_NAME:-unknown} (Debian/Ubuntu only)" >&2; exit 1 ;;
esac

exec bash "$DIR/install/debian.sh" "$@"
