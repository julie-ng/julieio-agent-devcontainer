# Changelog

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## [0.5.0](https://github.com/julie-ng/agent-devcontainer/compare/v0.4.0...v0.5.0) (2026-10-31)

### ⚠ BREAKING CHANGES

* **image:** The non-root user is now `vscode` instead of `node`,
  so mounts into /home/node must move to /home/vscode. The -frontend tags
  are no longer published.

### Features

* **image:** remove gitlab cli ([3f219fe](https://github.com/julie-ng/agent-devcontainer/commit/3f219fee99b0c7a6369324e4336b423951be00a4))
* **image:** single debian image with node and chromium ([beeccef](https://github.com/julie-ng/agent-devcontainer/commit/beeccef69f708f2fc19be397af0ef66bc2413ddb))
## [0.4.0](https://github.com/julie-ng/agent-devcontainer/compare/v0.3.0...v0.4.0) (2026-09-21)

### Features

* **image:** add gitlab cli ([31c0fd1](https://github.com/julie-ng/agent-devcontainer/commit/31c0fd11ff945ee543a42519982295528aed6e4c))
## [0.3.0](https://github.com/julie-ng/agent-devcontainer/compare/v0.2.0...v0.3.0) (2026-09-10)

### Features

* **image:** add typescript ([a014622](https://github.com/julie-ng/agent-devcontainer/commit/a0146228c6a8734812d46ed61532bdc4d52656b8))
## [0.2.0](https://github.com/julie-ng/agent-devcontainer/compare/v0.1.0...v0.2.0) (2026-09-08)

### Features

* **image:** add frontend variant wtih packaged headless browser ([1e02a70](https://github.com/julie-ng/agent-devcontainer/commit/1e02a70c140a5e7757d3a178e05902151b3d3e90))
* **perf:** move mmdc to devcontainer.json, add docker-docker ([34753a8](https://github.com/julie-ng/agent-devcontainer/commit/34753a8e88e55a5d8d9fbb62a8c10478dd03a995))
## 0.1.0 (2026-09-06)

### Image Changes

* default to zsh ([dad46d6](https://github.com/julie-ng/agent-devcontainer/commit/dad46d684ac383606e0b82b67771e02290107f62))

### CI/CD

* automatically publish image ([94a721c](https://github.com/julie-ng/agent-devcontainer/commit/94a721cb9dc2856b1758944a840d8d024193178d))
* publish tags, incl. moving major tag ([14b6c08](https://github.com/julie-ng/agent-devcontainer/commit/14b6c080ab2a23788d5df51dae386ed5e75a7ccd))
* remove pr trigger ([b3b870c](https://github.com/julie-ng/agent-devcontainer/commit/b3b870c714f308cafe35eb52d9ebbd93282d320b))

### Dependencies

* add mmdc so claude can draw/verify mermaid diagrams ([f7c0589](https://github.com/julie-ng/agent-devcontainer/commit/f7c0589359d18d0693ff64e48c30bbc47f973b79))
