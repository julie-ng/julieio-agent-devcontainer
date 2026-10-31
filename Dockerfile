# julieio/agent-devcontainer
#
# Devcontainer base image for interactive coding agents with Zed.dev IDE.
#
# Notes:
#   - FROM Microsoft devcontainer image for devcontainer-spec compat
#     (non-root `vscode` user, sudo, features).
#   - Debian, not Ubuntu: Ubuntu's apt chromium is only a stub for the snap,
#     and snaps don't run in containers. Debian's is a real arm64-native build.
#   - One image with everything for local use; anything missing is added per
#     project via a devcontainer feature or installed by the agent.
#   - Out of scope: sbx, gVisor/Kata, cloud CLIs.
#   - kubectl tracks dl.k8s.io stable (unpinned) — pin later if version skew
#     becomes a problem.
#   - Node via nvm, default version baked in. Projects needing another version
#     run `nvm install` themselves.
#   - Python is installed per project by uv (from .python-version or
#     pyproject.toml); only the uv binary is in the image.
#   - No mermaid-cli: Puppeteer ships no linux-arm64 Chromium, so rendering
#     never worked on arm64. Install it per-project if a host needs it.
#   - kind needs a working Docker daemon — from the docker-in-docker feature in
#     devcontainer.json, not this image.

# ---- Pinned versions -------------------------------------------------------
# Bump manually; they don't auto-track latest.
ARG BASE_IMAGE_TAG=debian13
ARG NVM_VERSION=v0.40.8
ARG NODE_VERSION=24.22.2
ARG PLAYWRIGHT_MCP_VERSION=0.0.83
ARG UV_VERSION=0.13.6
ARG YQ_VERSION=v4.54.1
ARG KIND_VERSION=v0.33.0

# uv's official image, used only as a source for its binaries below.
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM mcr.microsoft.com/devcontainers/base:${BASE_IMAGE_TAG}

# Re-declared to bring the pinned versions above into this stage's scope.
ARG NVM_VERSION
ARG NODE_VERSION
ARG PLAYWRIGHT_MCP_VERSION
ARG YQ_VERSION
ARG KIND_VERSION
ARG TARGETARCH

# ---- OS packages -----------------------------------------------------------
# - jq/yq: K8s manifests are YAML.
# - gh: inspect the webhook/PR pipeline.
# - openssh-client: ssh-keygen for per-agent SSH keys.
# - chromium + fonts: headless browser for screenshotting/inspecting UIs.
# - unzip/bzip2/less/vim/ca-certificates/gnupg: general sandbox hygiene.
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        jq \
        unzip \
        bzip2 \
        less \
        vim \
        gnupg \
        ca-certificates \
        openssh-client \
        chromium \
        fonts-liberation \
        fonts-noto-color-emoji \
    && sudo rm -rf /var/lib/apt/lists/*

# yq (Go binary, mikefarah/yq) — apt's yq is an unrelated Python wrapper.
RUN sudo curl -fsSL -o /usr/local/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" && \
    sudo chmod +x /usr/local/bin/yq

# GitHub CLI — via official apt repo, so it stays updatable through apt.
RUN sudo mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt-get update && sudo apt-get install -y gh && \
    sudo rm -rf /var/lib/apt/lists/*

# kubectl — official stable release channel.
RUN KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)" && \
    sudo curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    sudo chmod +x /usr/local/bin/kubectl

# Kind — local Kubernetes cluster.
RUN sudo curl -fsSL -o /usr/local/bin/kind \
        "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${TARGETARCH}" && \
    sudo chmod +x /usr/local/bin/kind

# uv — Python package and version manager. Copied from uv's official image
# (Astral's documented Docker install), not a curl | sh installer.
COPY --from=uv /uv /uvx /usr/local/bin/

# ---- Node via nvm ----------------------------------------------------------
# NVM_SYMLINK_CURRENT keeps $NVM_DIR/current pointing at the active version,
# so with it on PATH, node/npm/global tools work in non-interactive shells
# (postCreateCommand, agents) without loading nvm. `nvm use` switches the
# symlink, i.e. the whole container.
# CHROME_BIN: some tools read this directly for a system browser.
# PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: stops Playwright fetching its own
# Chromium, which has no linux-arm64 build anyway (same gap as Puppeteer's).
ENV NVM_DIR=/usr/local/share/nvm \
    NVM_SYMLINK_CURRENT=true \
    PATH=/usr/local/share/nvm/current/bin:${PATH} \
    CHROME_BIN=/usr/bin/chromium \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Owned by vscode so `nvm install` and `npm install -g` work without sudo.
# PROFILE=/dev/null stops the installer editing rc files; nvm is loaded from
# the system-wide rc files instead, so dotfiles replacing ~/.zshrc don't drop it.
RUN sudo mkdir -p "${NVM_DIR}" && sudo chown vscode:vscode "${NVM_DIR}" && \
    for rc in /etc/zsh/zshrc /etc/bash.bashrc; do \
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' | sudo tee -a "$rc" > /dev/null; \
    done

USER vscode

RUN curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
        | PROFILE=/dev/null bash && \
    . "${NVM_DIR}/nvm.sh" && \
    nvm install "${NODE_VERSION}" && \
    nvm alias default "${NODE_VERSION}" && \
    nvm use default

# @playwright/mcp — lets a coding agent drive a browser to check/screenshot
# frontends. Playwright ignores PUPPETEER_EXECUTABLE_PATH (that's Puppeteer-
# only, confirmed by testing) and has no env var for a custom browser path,
# so the system chromium must be passed explicitly: MCP server args need
# `--executable-path /usr/bin/chromium --browser chromium`.
# Global npm packages are per Node version, so this is under the default only.
RUN npm install -g "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}"

USER root

# zsh — already installed in the base image but not the vscode user's default shell.
RUN sudo chsh -s /usr/bin/zsh vscode

# ---- Sanity check at build time --------------------------------------------
# Chromium gets two checks, not one: --headless --screenshot proves the
# browser renders at all, and the playwright-core launch proves
# @playwright/mcp's actual code path (explicit executablePath, no env var)
# also works. A passing `chromium --version` alone wouldn't catch either
# failure mode — the same blind spot that hid mermaid-cli's arm64 breakage.
RUN jq --version && \
    yq --version && \
    gh --version && \
    kubectl version --client && \
    kind version && \
    uv --version && \
    node --version && \
    npm --version && \
    echo '<h1>ok</h1>' > /tmp/t.html && \
    chromium --headless --no-sandbox --disable-gpu \
        --screenshot=/tmp/t.png --window-size=200,100 file:///tmp/t.html && \
    test -s /tmp/t.png && \
    node -e "require('$(npm root -g)/@playwright/mcp/node_modules/playwright-core').chromium.launch({headless:true,executablePath:'/usr/bin/chromium',args:['--no-sandbox']}).then(b=>b.close())" && \
    rm -f /tmp/t.html /tmp/t.png

# Fallback only — devcontainer.json's workspaceFolder overrides this in practice.
WORKDIR /workspace
