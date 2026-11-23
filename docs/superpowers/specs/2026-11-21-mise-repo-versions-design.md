# Repo-declared tool versions win over global defaults

## Why

An aoe session built a repo with Rust 1.100.0 instead of the 1.99.1 its
`rust-toolchain.toml` pins. `rust = "stable"` in `langs.toml` makes mise export
`RUSTUP_TOOLCHAIN=stable`, which overrides the repo's file. Sessions run in many
repos that each need their own versions, on the host and in the aoe sandbox
container.

## Goals

- A repo's own version file (`rust-toolchain.toml`, `.nvmrc`, `.python-version`,
  …) decides the version whenever it exists.
- Repos that declare nothing keep getting the global defaults.
- Same behaviour on the host and in the aoe sandbox image.

## Non-goals

- Changing which tools are installed globally, or Neovim's language detection
  (it reads `langs.toml`, which stays as is).
- Pinning any version in the sandbox image.

## Anti-goals

- A global default silently overriding a repo's declared version (today's bug).

## Approaches

1. **mise idiomatic version files (chosen).** Enable mise's
   `idiomatic_version_file_enable_tools` so it reads each language's native
   version file. One setting, same on host and container, defaults untouched.
   Verified: with it on, mise resolved rust 1.99.1 from `rust-toolchain.toml`,
   node 22 from `.nvmrc`, go 1.27.0 from `go.mod`.
2. Native managers per language (plain rustup, Go's toolchain switching, …).
   Rejected: several mechanisms, and Neovim's language list loses its source.
3. Fix Rust only. Rejected: `.nvmrc` / `.python-version` would stay silently
   ignored.

## Design

- `mise/.config/mise/config.toml` gets a `[settings]` entry enabling idiomatic
  version files for: rust, node, python, ruby, java, dotnet. Checked against
  mise 2026.11.8: each resolved from `rust-toolchain.toml`, `.nvmrc`,
  `.python-version`, `.ruby-version`, `.java-version` and `global.json`;
  `.lua-version` was ignored, so lua stays off the list.
- **Go is excluded** (my call): mise reads `go.mod`'s `go` line as an exact
  version, but Go treats it as a minimum and already switches toolchains itself
  (`GOTOOLCHAIN=auto`, which mise leaves alone). Keeping the global latest Go
  satisfies any minimum without a download per patch version.
- The sandbox Dockerfile sets the same list via
  `MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS`, since the image copies no mise
  config.
- A repo's `mise.toml` still wins over everything, as today.

## Left to the builder

- Check what happens when the declared version isn't installed: on the host
  (`mise activate` PATH mode) and in the container (shims). Either it installs
  on demand or it fails with a clear message pointing at `mise install`; a
  silent fallback to the global default is a bug.
- Verify in a throwaway repo pinning `rust-toolchain.toml` to 1.99.1 that
  `cargo --version` reports 1.99.1 on the host and in the sandbox image.
