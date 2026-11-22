# Repo-Declared Tool Versions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A repo's own version file decides the tool version on the host and in the aoe sandbox; global mise defaults apply only when the repo declares nothing.

**Architecture:** Enable mise's idiomatic version files for six languages, via `[settings]` in the stowed global mise config (host) and an `ENV` in the sandbox Dockerfile (container, which copies no mise config). One test script verifies both.

**Tech Stack:** mise 2026.11.x, bash, Docker.

**Spec:** `docs/superpowers/specs/2026-11-21-mise-repo-versions-design.md`

## Global Constraints

- Idiomatic tool list, exactly: `rust`, `node`, `python`, `ruby`, `java`, `dotnet`. Not `go`, not `lua`.
- `langs.toml` and the `[tools]` defaults are not changed (Neovim reads them).
- The sandbox image pins no tool versions.
- A repo's `mise.toml` still overrides everything.
- Conventional Commits, no attribution lines; comments only for the non-obvious why.

## Review Focus

1. Repo pins a version that isn't installed → must not silently run the global default (e.g. `RUSTUP_TOOLCHAIN=stable`). Pinned by the `RUSTUP_TOOLCHAIN` and `cargo --version` checks in Task 1.
2. Repo's `go.mod` says `go 1.27.0` → Go stays on the global version (mise must not install 1.27.0). Pinned in Task 1.
3. Repo with no version files → global defaults still apply on the host. Pinned in Task 1.
4. Container has no global config → pinned versions still resolve there. Pinned by Task 2 running the same script in the image.
5. Repo has both `mise.toml` and an idiomatic file → `mise.toml` wins. Pinned in Task 1.

---

### Task 1: Host reads repo version files

**Files:**
- Create: `tests/mise-repo-versions.sh`
- Modify: `mise/.config/mise/config.toml` (append a `[settings]` table)

**Interfaces:**
- Produces: `tests/mise-repo-versions.sh [--no-defaults]` — exits 0 when all checks pass, prints `PASS <name>` / `FAIL <name>` per check (same style as `tests/agent-sessions.sh`). `--no-defaults` skips the checks that depend on host global defaults (used by Task 2).

- [ ] **Step 1: Write the test script**

Runs in a `mktemp -d` git repo (cleaned up on exit), using `mise current <tool>` to read the resolved version. Checks:

| name | setup in the temp repo | assertion |
|---|---|---|
| `rust-from-toolchain-file` | `rust-toolchain.toml`: `[toolchain]` `channel = "1.99.1"` | `mise current rust` = `1.99.1` |
| `node-from-nvmrc` | `.nvmrc`: `22` | `mise current node` starts with `22.` |
| `python-from-python-version` | `.python-version`: `3.12` | starts with `3.12.` |
| `ruby-from-ruby-version` | `.ruby-version`: `3.3.0` | = `3.3.0` |
| `java-from-java-version` | `.java-version`: `21` | starts with `21.` |
| `dotnet-from-global-json` | `global.json`: `{"sdk":{"version":"8.0.100"}}` | = `8.0.100` |
| `rust-env-not-stable` | as rust row | `mise env` does not contain `RUSTUP_TOOLCHAIN=stable` |
| `cargo-runs-pinned` | as rust row | `mise exec -- cargo --version` contains `1.99.1` (installs on demand; slow first run) |
| `mise-toml-wins` | rust row + `mise.toml` `[tools] rust = "1.98.0"`, `mise trust` it | `mise current rust` = `1.98.0` |
| `go-ignores-go-mod` *(host only)* | `go.mod` with `go 1.27.0` | `mise current go` ≠ `1.27.0` and equals its value in an empty dir |
| `defaults-without-files` *(host only)* | empty dir | `mise current rust` = `stable` |

Keep `mise.toml` checks in their own temp dir so they don't affect the others.

- [ ] **Step 2: Run it, expect failures**

Run: `bash tests/mise-repo-versions.sh`
Expected: `FAIL` for the six `*-from-*` rows and `rust-env-not-stable`; exit 1.

- [ ] **Step 3: Add the setting**

Append to `mise/.config/mise/config.toml`, with a one-line comment giving the why (repo version files must beat global defaults; go excluded because `go.mod`'s `go` line is a minimum and Go switches toolchains itself):

```toml
[settings]
idiomatic_version_file_enable_tools = ["rust", "node", "python", "ruby", "java", "dotnet"]
```

- [ ] **Step 4: Run it, expect all pass**

Run: `bash tests/mise-repo-versions.sh && bash tests/check.sh`
Expected: every line `PASS`, exit 0; `check.sh` clean (shellcheck covers the new script).

- [ ] **Step 5: Commit**

```bash
git add tests/mise-repo-versions.sh mise/.config/mise/config.toml
git commit -m "fix(mise): let repo version files override global defaults"
```

### Task 2: Sandbox image reads repo version files

**Files:**
- Modify: `aoe/.config/agent-of-empires/sandbox/Dockerfile`

**Interfaces:**
- Consumes: `tests/mise-repo-versions.sh --no-defaults` from Task 1.

- [ ] **Step 1: Run the test in the current image, expect failures**

Run: `docker run --rm -v "$PWD/tests:/t:ro" --entrypoint bash aoe-sandbox-dotfiles:latest /t/mise-repo-versions.sh --no-defaults`
Expected: `FAIL` on the `*-from-*` rows; exit 1.

- [ ] **Step 2: Add the env var**

Add `MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=rust,node,python,ruby,java,dotnet` to the Dockerfile's first `ENV` block.

- [ ] **Step 3: Rebuild and rerun**

Run: `scripts/bin/aoe-sandbox-build`, then the Step 1 command.
Expected: build exits 0; every line `PASS`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add aoe/.config/agent-of-empires/sandbox/Dockerfile
git commit -m "fix(aoe): let repo version files pick sandbox tool versions"
```

### Task 3: Interactive shell check (manual)

- [ ] **Step 1:** In a new zsh (so `mise activate` reloads), `cd` into a temp repo with the Task 1 `rust-toolchain.toml` and run `cargo --version`.
Expected: `1.99.1`, or a mise message saying to run `mise install`; never `1.100.0`.

- [ ] **Step 2:** Commit the spec and this plan:

```bash
git add docs/superpowers/specs/2026-11-21-mise-repo-versions-design.md docs/superpowers/plans/2026-11-22-mise-repo-versions.md
git commit -m "docs(mise): add design and plan for repo-declared tool versions"
```
