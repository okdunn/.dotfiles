# aoe sandboxes can write a repo's .git/config and .git/hooks, and some of those settings run
# commands when git runs here on the host (core.fsmonitor on a plain `git status`). GIT_CONFIG_*
# outranks repo config, so pin the ones that execute. Arbitrarily named filter/diff/merge
# drivers can't be pinned this way; review .gitattributes changes from sandboxed sessions.
if [[ -z ${_GIT_GUARD-} ]]; then
  export _GIT_GUARD=1
  () {
    local n=${GIT_CONFIG_COUNT:-0} key value
    local pager=$(command git config --global --get core.pager 2>/dev/null)
    local filter=$(command git config --global --get interactive.diffFilter 2>/dev/null)
    local -a pins=(
      core.hooksPath /dev/null
      core.fsmonitor false
      core.pager "${pager:-less}"
      interactive.diffFilter "${filter:-cat}"
      core.editor "${VISUAL:-${EDITOR:-vi}}"
      core.sshCommand ssh
      # An empty value clears every helper set before it (URL-scoped ones too), including the
      # repo's; the global ones are added back after it
      credential.helper ""
      gpg.program gpg
      gpg.ssh.program ssh-keygen
    )
    local line
    for line in "${(@f)$(command git config --global --get-regexp '^credential\..*helper$' 2>/dev/null)}"; do
      [[ -n $line ]] && pins+=("${line%% *}" "${line#* }")
    done
    for key value in "${pins[@]}"; do
      export GIT_CONFIG_KEY_$n="$key" GIT_CONFIG_VALUE_$n="$value"
      (( n++ ))
    done
    export GIT_CONFIG_COUNT=$n
  }
fi

# Run one git command with the repo's own hooks, once you've checked what they do
githooks() {
  local hooks
  hooks=$(command git config --local --get core.hooksPath) ||
    hooks="$(command git rev-parse --git-common-dir)/hooks"
  command git -c core.hooksPath="$hooks" "$@"
}
