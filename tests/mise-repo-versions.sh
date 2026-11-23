#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # bash -c bodies take their values as $1 on purpose; check calls helpers by name
# Checks that a repo's own version files (rust-toolchain.toml, .nvmrc, …) beat the global
# mise defaults. Runs on the host, or in the aoe sandbox image with --no-defaults (it has no
# global mise config). Pinning rust installs 1.99.1 through rustup on first run.
set -uo pipefail

defaults=1
[[ "${1:-}" == "--no-defaults" ]] && defaults=0

failed=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export MISE_TRUSTED_CONFIG_PATHS="$TMP"

check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
current() { (cd "$1" && mise current "$2" 2>/dev/null); }
is() { [[ "$1" == "$2" ]]; }
matches() { [[ "$1" =~ $2 ]]; }

repo="$TMP/repo" empty="$TMP/empty" pinned="$TMP/pinned" gomod="$TMP/gomod"
mkdir -p "$repo" "$empty" "$pinned" "$gomod"

printf '[toolchain]\nchannel = "1.99.1"\n' >"$repo/rust-toolchain.toml"
echo 22 >"$repo/.nvmrc"
echo 3.12 >"$repo/.python-version"
echo 3.3.0 >"$repo/.ruby-version"
echo 21 >"$repo/.java-version"
echo '{"sdk":{"version":"8.0.100"}}' >"$repo/global.json"

check rust-from-toolchain-file is "$(current "$repo" rust)" 1.99.1
check node-from-nvmrc matches "$(current "$repo" node)" '^22(\.|$)'
check python-from-python-version matches "$(current "$repo" python)" '^3\.12(\.|$)'
check ruby-from-ruby-version is "$(current "$repo" ruby)" 3.3.0
check java-from-java-version matches "$(current "$repo" java)" '^21(\.|$)'
check dotnet-from-global-json is "$(current "$repo" dotnet)" 8.0.100
check rust-env-not-stable bash -c '! (cd "$1" && mise env 2>/dev/null) | grep -q "RUSTUP_TOOLCHAIN=stable"' _ "$repo"
check cargo-runs-pinned matches "$(cd "$repo" && mise exec -- cargo --version 2>&1)" 'cargo 1\.99\.1'
check rust-hook-env-clears-inherited-stable env RUSTUP_TOOLCHAIN=stable bash -c 'cd "$1" && eval "$(mise hook-env -s bash --force 2>/dev/null)" && [[ "${RUSTUP_TOOLCHAIN-unset}" != stable ]]' _ "$repo"

cp "$repo/rust-toolchain.toml" "$pinned/"
printf '[tools]\nrust = "1.98.0"\n' >"$pinned/mise.toml"
check mise-toml-wins is "$(current "$pinned" rust)" 1.98.0

if ((defaults)); then
  printf 'module example\n\ngo 1.27.0\n' >"$gomod/go.mod"
  default_go=$(current "$empty" go)
  check go-ignores-go-mod is "$(current "$gomod" go)" "$default_go"
  check go-default-not-go-mod-version bash -c '[[ "$1" != 1.27.0 ]]' _ "$default_go"
  check defaults-without-files is "$(current "$empty" rust)" stable
fi

exit "$failed"
