# aoe sandbox plus mise, so agents can install whatever toolchain a project needs.
# Build with `aoe-sandbox-build`.
FROM ghcr.io/agent-of-empires/aoe-sandbox:latest

# Outside /root: aoe mounts agent state into the container's home directory
ENV MISE_DATA_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/mise/cache \
    MISE_YES=1 \
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=rust,node,python,ruby,java,dotnet \
    PATH=/opt/mise/shims:$PATH

# mise installs rust through rustup, which keeps toolchains here rather than in MISE_DATA_DIR
ENV CARGO_HOME=/opt/mise/cargo \
    RUSTUP_HOME=/opt/mise/rustup

# The container is the isolation boundary, so a repo's mise.toml needn't be trusted by hand
ENV MISE_TRUSTED_CONFIG_PATHS=/

# dotnet aborts at startup without ICU
RUN apt-get update && apt-get install -y --no-install-recommends libicu-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Package caches live on the container's own filesystem, never a host mount, so a session's
# downloads can't reach other sessions or the host
ENV XDG_CACHE_HOME=/var/cache/aoe \
    npm_config_cache=/var/cache/aoe/npm \
    npm_config_store_dir=/var/cache/aoe/pnpm-store \
    GOPATH=/var/cache/aoe/go \
    UV_CACHE_DIR=/var/cache/aoe/uv \
    BUNDLE_PATH=/var/cache/aoe/bundle

COPY aoe-bootstrap /usr/local/bin/aoe-bootstrap

# aoe-sandbox-build passes the script's hash so dot doctor can tell when the image is stale
ARG BOOTSTRAP_SHA256
LABEL dotfiles.bootstrap-sha256=$BOOTSTRAP_SHA256
