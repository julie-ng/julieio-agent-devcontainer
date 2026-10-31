# julieio/agent-devcontainer
#
# Devcontainer base image for interactive coding agents with Zed.dev IDE.
#
# Notes:
#   - FROM Microsoft devcontainer image for devcontainer-spec compat
#     (non-root `node` user, sudo, features).
#   - Out of scope: sbx, gVisor/Kata, cloud CLIs.
#   - kubectl tracks dl.k8s.io stable (unpinned) — pin later if version skew
#     becomes a problem.
#   - Python is deliberately not baked in here; added via the
#     ghcr.io/devcontainers/features/python feature in devcontainer.json to
#     keep the version pin visible there instead of in a RUN step.
#   - No mermaid-cli: Puppeteer ships no linux-arm64 Chromium, so rendering
#     never worked on arm64. Install it per-project if a host needs it.
#   - kind needs a working Docker daemon — from the docker-in-docker feature in
#     devcontainer.json, not this image.

FROM mcr.microsoft.com/devcontainers/javascript-node:22

ARG TARGETARCH

# ---- OS packages -----------------------------------------------------------
# - jq/yq: K8s manifests are YAML.
# - gh: inspect the webhook/PR pipeline.
# - openssh-client: ssh-keygen for per-agent SSH keys.
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
    && sudo rm -rf /var/lib/apt/lists/*

# yq (Go binary, mikefarah/yq) — apt's yq is an unrelated Python wrapper.
RUN YQ_VERSION="v4.44.3" && \
    sudo curl -fsSL -o /usr/local/bin/yq \
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
RUN KIND_VERSION="v0.24.0" && \
    sudo curl -fsSL -o /usr/local/bin/kind \
        "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${TARGETARCH}" && \
    sudo chmod +x /usr/local/bin/kind

# TypeScript — global tsc, since agents type-check/compile across many repos
# rather than each one owning its own dev dependency.
RUN sudo npm install -g typescript

# zsh — already installed in the base image but not the node user's default shell.
RUN sudo chsh -s /usr/bin/zsh node

# ---- Sanity check at build time --------------------------------------------
RUN jq --version && \
    yq --version && \
    gh --version && \
    kubectl version --client && \
    kind version && \
    tsc --version

# Fallback only — devcontainer.json's workspaceFolder overrides this in practice.
WORKDIR /workspace
