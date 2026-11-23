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
