# [julieio-agent](https://github.com/julieio-agent) – dev container image 

To limit LLM access to my identity and priviledged access I run Claude Code and Codex in this custom [Dev Container](https://containers.dev/) image in [Zed IDE](https://zed.dev/).

Why? See [julie.io/ai-native-sdlc](https://julie.io/ai-native-sdlc)

## Base Image

- Base is `mcr.microsoft.com/devcontainers/base:debian13` for devcontainer-spec compatibility (non-root `vscode` user, sudo, features). 
- Debian rather than Ubuntu because Ubuntu's apt `chromium` is only a stub for the snap, and snaps don't run in containers.

## Included Tools

Pre-bake tools used regularly by agents and me – saves time and network traffic across sessions.

| Tool | Why |
|---|---|
| `jq` | JSON handling |
| `yq` (mikefarah/yq, the Go binary — not apt's Python one) | YAML handling |
| `gh` | GitHub CLI |
| `kubectl` | Talk to a Kubernetes cluster |
| `kind` | Local Kubernetes cluster — needs a working Docker daemon (see [Docker in Docker](#docker-in-docker)) |
| `uv` | Python package and version manager |
| Node 24 (via `nvm`) | Default Node version — other versions per project with `nvm install` (see below) |
| `chromium` + `@playwright/mcp` | Headless browser so agents can check and screenshot frontends (see below) |
| `openssh-client` | `ssh-keygen` and general SSH usage |
| `unzip`, `bzip2`, `less`, `vim`, `ca-certificates`, `gnupg` | General sandbox hygiene |

### Node

- Node 24 via `nvm`. `$NVM_DIR/current` is on `PATH`, so `node` also works in non-interactive shells.
- Other versions per project: `nvm install 22`, or `nvm install` with an `.nvmrc`. This switches the whole container.
- Global npm packages are per version, so `@playwright/mcp` only exists under Node 24.

### Chromium

- Debian's apt `chromium` (arm64-native) plus `@playwright/mcp`, so agents can check and screenshot frontends.
- Playwright's own Chromium has no linux-arm64 build, so pass the system one in the MCP server args:

  ```
  --executable-path /usr/bin/chromium --browser chromium
  ```

### Python

- Not baked in. `uv` installs the version each project asks for (`.python-version` or `pyproject.toml`) on first `uv sync` or `uv run`.

## Additional Tools (via Dev Container Features)

### Docker in Docker

From the official `docker-in-docker` feature. `kind` needs it.

```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {
    "moby": false
  }
}
```

- `"moby": false` is required. Debian trixie doesn't ship Moby packages (`The 'moby' option is not supported on debian 'trixie'`), so this installs Docker CE instead.
- DinD rather than `docker-outside-of-docker`, so bind-mount paths resolve inside the container and match the host-mirrored `workspaceFolder`. Needs `--privileged`.

## Example `devcontainer.json`

> [!IMPORTANT]
> This sample file is just a small baseline. I'll publish an in-depth blog article later that covers the full setup, which includes several mounts.

Copy [`devcontainer.sample.json`](./.devcontainer/devcontainer.sample.json) to your project's `.devcontainer/devcontainer.json` and adjust paths/mounts as needed.

```json
{
  "name": "Agent Devcontainer",
  "image": "docker.io/julieio/agent-devcontainer:latest",
  "workspaceMount": "source=${localWorkspaceFolder},target=/Users/<user>/path/to/project,type=bind,consistency=cached",
  "workspaceFolder": "/Users/<user>/path/to/project",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": false
    }
  },
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached"
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

- `kubectl` and `gh` aren't pinned: `kubectl` installs from `dl.k8s.io/release/stable.txt`, `gh` from GitHub's apt repo. Rebuilding the image picks up new versions. Pin `kubectl` if cluster-version skew becomes a problem.
- The base image, `nvm`, Node, `@playwright/mcp`, `uv`, `yq` and `kind` are pinned as `ARG`s at the top of the Dockerfile — bump these manually. `debian13` is a moving tag, so the base also picks up Microsoft's rebuilds.
- No Mermaid CLI (`mmdc`): Puppeteer's bundled Chrome for Testing has no linux-arm64 build. If a project needs it, point it at the image's Chromium with `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium`.

## References

- [Claude Code Docs: Development containers](https://code.claude.com/docs/en/devcontainer)
- Codex
  - [Configuration](https://learn.chatgpt.com/docs/config-file/config-basic) – `.codex/config.toml`
  - [Copy local auth cache](https://learn.chatgpt.com/docs/auth?surface=cli#cli-fallback-authenticate-locally-and-copy-your-auth-cache) – `~/.codex/auth.json`
  - [Sandbox and approvals](https://learn.chatgpt.com/docs/agent-approvals-security#sandbox-and-approvals)
