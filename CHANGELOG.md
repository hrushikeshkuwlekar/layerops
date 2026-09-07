# Changelog

All notable changes to layerops are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v4.0.0] — 2026-09-07

### 🎉 First Official Release

This is the first tagged release of layerops — a zero-rebuild container vulnerability
remediation tool that unifies Trivy scanning and Copacetic patching into a single CLI.

### Added

- **Unified installer** (`scripts/install.sh`) — one-command setup that handles layerops
  and all its dependencies (jq, Trivy, Copacetic, Docker, BuildKit) with OS/arch detection,
  idempotent installs, and fail-safe error handling
- **`--version` flag** — print the version and exit
- **`--doctor` subcommand** — check all dependencies are installed and report their versions
  with ✅/❌/⚠️ status indicators
- **Assess** one image or hundreds via `--image` / `--list`
- **OS-pkg & lib-pkg** findings reported separately — distro packages vs language packages
- **Patch** fixable OS packages with copa — writes a new tag, original image never modified
- **Two-pass resilient patching:**
  - Pass 1 — precise, report-based (`copa -r`)
  - Pass 2 — if pass 1 fails, retries with `copa --ignore-errors`, pinned to host CPU arch
- **Verify** patched images with `--verify` re-scan
- **HTML report** — fully offline, searchable, filterable, per-CVE detail with patch results
- **CSV report** — per-image + per-severity + per-CVE rows for downstream tooling
- **CI gate** — `--fail-on-fixable` exits 1 if any fixable vulnerability is found
- **Distroless / scratch** images correctly labelled
- **Multi-arch** tag normalisation for Docker Hub library images

### Linux & Cross-Platform Enhancements

- **Auto-Directory Creation** — Ensures `$INSTALL_DIR` (e.g. `/usr/local/bin`) is created via `mkdir -p` even on minimal or fresh Linux systems
- **Multi-Arch Binary Fallbacks:**
  - **Copacetic (`copa`)** — Dynamic OS/arch detection (`linux/amd64`, `linux/arm64`, `darwin/arm64`, `darwin/amd64`)
  - **Trivy** — Package manager install with automated fallback to Aqua Security's official installer script if repository keys or network fail
  - **jq** — Native package manager install (`apt`, `dnf`, `yum`, `apk`, `brew`) with direct binary fallback from GitHub releases
- **Container-Aware Service Management** — Supports `systemctl`, `service`, and handles containerized environments gracefully without crashing if a systemd daemon is not present
- **Verified Distros** — Tested and verified on Ubuntu (Debian), Alpine Linux (musl), Fedora (RPM), and macOS (Apple Silicon & Intel)

### Install

```bash
curl -sSL https://raw.githubusercontent.com/hrushikeshkuwlekar/layerops/main/scripts/install.sh | bash
```

[v4.0.0]: https://github.com/hrushikeshkuwlekar/layerops/releases/tag/v4.0.0
