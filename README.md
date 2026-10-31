# agent-devcontainer

A devcontainer base image for agent-assisted development. Coding agents (e.g. Claude Code) run through the IDE, not inside this image — this `docker.io/julieio/agent-devcontainer` just provides the OS tooling a devcontainer needs.

> [!NOTE]
> Not everything is in the Dockerfile — Python and Docker are added as devcontainer features, so they're pinned and visible in `devcontainer.json` instead. See the sections below.

## Included Tools

| Tool | Why |
|---|---|
| `jq` | JSON handling |
| `yq` (mikefarah/yq, the Go binary — not apt's Python one) | YAML handling |
| `gh` | GitHub CLI |
| `kubectl` | Talk to a Kubernetes cluster |
| `kind` | Local Kubernetes cluster — needs a working Docker daemon (see [Docker in Docker](#docker-in-docker)) |
| `openssh-client` | `ssh-keygen` and general SSH usage |
| `unzip`, `bzip2`, `less`, `vim`, `ca-certificates`, `gnupg` | General sandbox hygiene |
| Python 3.12 | Added via a devcontainer feature, not baked into the image (see below) |
| Docker | Added via a devcontainer feature, not baked into the image (see below) |

Base image: `mcr.microsoft.com/devcontainers/javascript-node:22`, for devcontainer-spec compatibility (non-root `node` user, sudo, features).

### Python

Python is **not** baked into the image. It's added declaratively via the official `ghcr.io/devcontainers/features/python:1` feature in `devcontainer.json` (pinned to `3.12`), keeping the version visible and diffable in `devcontainer.json` rather than buried in a Dockerfile `RUN` step.

### Docker in Docker

Docker is **not** in the image either. It comes from the official `ghcr.io/devcontainers/features/docker-in-docker:2` feature, which runs a real nested daemon inside the container. `kind` is installed in the image but cannot create a cluster without it.

```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {
    "moby": false
  }
}
```

`"moby": false` is **required**, not optional. The feature defaults to `moby: true` and installs Moby packages, which Debian trixie — the current `javascript-node:22` base — does not ship, so the build fails with `The 'moby' option is not supported on debian 'trixie'`. With `moby: false` the feature installs upstream Docker CE from Docker's apt repo instead.

DinD needs the container to run `--privileged`, and gives full isolation — clusters and bind-mount paths live inside the container, matching the host-mirrored `workspaceFolder` this setup relies on. The alternative feature, `docker-outside-of-docker:2`, only mounts the host's Docker socket: lighter and unprivileged, but the containers it starts are siblings on the host and their bind-mount paths resolve against the host filesystem, not the devcontainer's.

## Example `devcontainer.json`

Copy [`devcontainer.sample.json`](./.devcontainer/devcontainer.sample.json) to your project's `.devcontainer/devcontainer.json` and adjust paths/mounts as needed.

```json
{
  "name": "Agent Devcontainer",
  "image": "docker.io/julieio/agent-devcontainer:latest",
  "workspaceMount": "source=${localWorkspaceFolder},target=/Users/<user>/path/to/project,type=bind,consistency=cached",
  "workspaceFolder": "/Users/<user>/path/to/project",
  "features": {
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.12"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": false
    }
  },
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/node/.claude,type=bind,consistency=cached"
  ],
  "postCreateCommand": "npm install",
  "dotfiles": {
    "repository": "https://github.com/<USERNAME>/dotfiles.git",
    "targetPath": "~/dotfiles",
    "installCommand": "~/dotfiles/setup.sh"
  }
}
```

### Claude Code Setup

The `agent-devcontainer` itself is agnostic. But the `devcontainer.json` file contains Claude code specific setup.

#### Map this project's memories

In order for Claude to pull the project specific memories, the container needs to work in a directory path that matches the host path:

| | Path |
|---|---|
| Project Path | `/Users/alice/workspace/my-project` |
| Claude memory path | `~/.claude/projects/-Users-alice-workspace-my-project` |

#### Mount all memories

Mounting `~/.claude` carries over its config into the container and _memorials from **all** claude projects_.  This intentional I can ask Claude to check how project X handled problem Y, etc.

## Build & publish

```bash
# from this directory
docker buildx build --platform linux/amd64,linux/arm64 \
  -t julieio/agent-devcontainer:latest \
  --push .
```

To test locally before pushing:

```bash
docker buildx build --platform linux/arm64 -t julieio/agent-devcontainer:test --load .
docker run --rm -it julieio/agent-devcontainer:test bash
```

## Maintenance notes

- `kubectl` installs from `dl.k8s.io/release/stable.txt` at build time — rebuilding the image (not just restarting a container) picks up new kubectl versions. Pin explicitly if cluster-version skew becomes a problem.
- `yq` and `kind` versions are pinned explicitly in the Dockerfile (`v4.44.3`, `v0.24.0`) — bump these manually; they don't auto-track latest.
- Mermaid CLI (`mmdc`) was removed, along with the Chromium shared libraries it needed. Puppeteer installs Chrome for Testing, which publishes no `linux-arm64` build, so `mmdc` rendering never worked on arm64 hosts — it failed with `qemu-x86_64: Could not open '/lib64/ld-linux-x86-64.so.2'`. The old build-time `mmdc --version` check passed because `--version` never launches a browser. If a project needs it, install `chromium` from apt and set `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium` there.
