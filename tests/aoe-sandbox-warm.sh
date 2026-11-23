#!/usr/bin/env bash
# shellcheck disable=SC2016  # the bash -c bodies get their values as $1.. on purpose
# Tests for aoe-sandbox-warm's generational toolchain cache. HOME and AOE_MISE_DIR are temp dirs
# and the container runtime is a stub on PATH; nothing outside the temp dir is touched.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
WARM="$REPO/scripts/bin/aoe-sandbox-warm"
failed=0

setup() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home" STUB="$SANDBOX/stub" AOE_MISE_DIR="$SANDBOX/home/.local/share/aoe-mise"
  M=$AOE_MISE_DIR
  mkdir -p "$HOME/.config/agent-of-empires" "$STUB" "$SANDBOX/bin"
  printf '[sandbox]\ncontainer_runtime = "podman"\n' >"$HOME/.config/agent-of-empires/config.toml"
  touch "$STUB/running"
  # `run` installs by touching installed-<spec> in the dir mounted at /opt/mise, or copies the
  # volume fixture for a /from -> /to copy; `ps` lists $STUB/running; `exec <c>` prints the
  # generation in $STUB/gen-<c>; `volume` acts on the $STUB/volume fixture
  cat >"$SANDBOX/bin/podman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  run)
    shift
    mise="" to="" specs=()
    while (($#)); do
      case "$1" in
        -v)
          case "$2" in
            *:/opt/mise) mise=${2%:/opt/mise} ;;
            *:/to) to=${2%:/to} ;;
          esac
          shift 2 ;;
        _) shift; specs=("$@"); break ;;
        *) shift ;;
      esac
    done
    if [[ -n $to ]]; then cp -a "$STUB/volume/." "$to/"; exit; fi
    for s in "${specs[@]}"; do touch "$mise/installed-$s"; done
    sleep 0.2
    [[ ! -e $STUB/run-fail ]] ;;
  ps) cat "$STUB/running" ;;
  exec) cat "$STUB/gen-$2" ;;
  volume)
    case "$2" in
      inspect) [[ -d $STUB/volume ]] ;;
      rm) rm -rf "$STUB/volume"; touch "$STUB/volume-removed" ;;
    esac ;;
esac
EOF
  chmod +x "$SANDBOX/bin/podman"
  export PATH="$SANDBOX/bin:$PATH"
}
warm() { "$WARM" "$@" >>"$SANDBOX/out" 2>&1; }
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}

# --- --init ------------------------------------------------------------------------------------

setup; mkdir "$STUB/volume"; echo cached >"$STUB/volume/fixture"; warm --init
check init-seeds-from-volume bash -c '[[ $(cat "$1/gen-1/fixture") == cached && $(readlink "$1/current") == gen-1 &&
  $(cat "$1/gen-1/.generation") == 1 && -e "$2/volume-removed" && ! -e "$2/volume" ]]' _ "$M" "$STUB"

setup; warm --init
check init-empty bash -c '[[ $(readlink "$1/current") == gen-1 && $(cat "$1/gen-1/.generation") == 1 &&
  ! -e "$2/volume-removed" ]]' _ "$M" "$STUB"

setup; warm --init; touch "$M/gen-1/mine"; warm --init
check init-idempotent bash -c '[[ "$(cd "$1" && echo gen-*)" == gen-1 && $(readlink "$1/current") == gen-1 && -e "$1/gen-1/mine" ]]' _ "$M"

# --- warming -----------------------------------------------------------------------------------

setup; warm node@24
check warm-needs-init bash -c '[[ ! -e "$1/current" ]] && grep -q -- --init "$2"' _ "$M" "$SANDBOX/out"

setup; warm --init; touch "$M/gen-1/old"; warm node@24
check warm-new-generation bash -c '[[ -e "$1/gen-2/installed-node@24" && -e "$1/gen-2/old" && $(readlink "$1/current") == gen-2 &&
  $(cat "$1/gen-2/.generation") == 2 && ! -e "$1/gen-1/installed-node@24" ]]' _ "$M"

setup; warm --init; echo aoe-sandbox-0123abcd >"$STUB/running"; echo 1 >"$STUB/gen-aoe-sandbox-0123abcd"
warm node@24; status=$?
check warm-while-running bash -c '[[ $1 == 0 && -d "$2/gen-1" && $(readlink "$2/current") == gen-2 ]]' _ "$status" "$M"

setup; warm --init; warm node@24; warm go@1.27
check gc-unused bash -c '[[ "$(cd "$1" && echo gen-*)" == gen-3 ]]' _ "$M"

setup; warm --init; echo aoe-sandbox-0123abcd >"$STUB/running"; warm node@24; warm go@1.27
check gc-unmarked-container-pins-nothing bash -c '[[ "$(cd "$1" && echo gen-*)" == gen-3 ]]' _ "$M"

setup; warm --init; touch "$STUB/run-fail"; warm node@24; status=$?
check warm-failure-keeps-current bash -c '[[ $1 != 0 && $(readlink "$2/current") == gen-1 && ! -e "$2/gen-2" ]]' _ "$status" "$M"

setup; warm --init; warm node@24 & warm go@1.27 & wait
check warm-serialises bash -c '[[ $(readlink "$1/current") == gen-3 && -e "$1/gen-3/installed-node@24" &&
  -e "$1/gen-3/installed-go@1.27" && $(cat "$1/gen-3/.generation") == 3 ]]' _ "$M"

exit "$failed"
