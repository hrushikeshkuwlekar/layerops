#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# install.sh — unified installer for layerops and all its dependencies
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/hrushikeshkuwlekar/layerops/main/scripts/install.sh | bash
#
# Or download and inspect first:
#   curl -sSL https://raw.githubusercontent.com/hrushikeshkuwlekar/layerops/main/scripts/install.sh -o install.sh
#   bash install.sh
#
# Installs: layerops, jq, trivy, copa, docker, buildkit (moby/buildkit)
# Supports: macOS (arm64/amd64), Linux (amd64/arm64)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LAYEROPS_VERSION="${LAYEROPS_VERSION:-v4.0.0}"
LAYEROPS_REPO="hrushikeshkuwlekar/layerops"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Flags (set via CLI args)
SKIP_DEPS=0
DEPS_ONLY=0
UNINSTALL=0
YES_MODE=0
VERBOSE=0

# Installation log file
INSTALL_LOG="${INSTALL_LOG:-$(mktemp -t layerops-install-XXXXXX.log 2>/dev/null || mktemp /tmp/layerops-install-XXXXXX.log 2>/dev/null || echo "/tmp/layerops-install-${UID:-0}.log")}"
touch "$INSTALL_LOG" 2>/dev/null || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Colors & Output Helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RST=$'\033[0m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  WHITE=$'\033[1;37m'
else
  RST='' BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' WHITE=''
fi

info()    { printf "${BLUE}  ℹ${RST}  %s\n" "$*"; }
ok()      { printf "${GREEN}  ✅${RST} %s\n" "$*"; }
warn()    { printf "${YELLOW}  ⚠️${RST}  %s\n" "$*" >&2; }
fail()    { printf "${RED}  ❌${RST} %s\n" "$*" >&2; }
step()    { printf "\n${BOLD}${CYAN}▸ %s${RST}\n" "$*"; }
substep() { printf "${DIM}  · %s${RST}\n" "$*"; }
die()     { fail "$*"; exit 1; }

# Command runner: silent by default (redirects to INSTALL_LOG), verbose with -v
run_cmd() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    "$@" 2>&1 | tee -a "$INSTALL_LOG"
  else
    "$@" >> "$INSTALL_LOG" 2>&1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Banner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
banner() {
  printf "\n"
  printf "${BOLD}${CYAN}"
  cat <<'EOF'
   ┌─────────────────────────────────────────────────┐
   │                                                 │
   │   ██╗      █████╗ ██╗   ██╗███████╗██████╗      │
   │   ██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗     │
   │   ██║     ███████║ ╚████╔╝ █████╗  ██████╔╝     │
   │   ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗     │
   │   ███████╗██║  ██║   ██║   ███████╗██║  ██║     │
   │   ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝     │
   │                   ╔═╗ ╔═╗ ╔═╗                   │
   │                   ║ ║ ╠═╝ ╚═╗                   │
   │                   ╚═╝ ╩   ╚═╝                   │
   │                                                 │
   │          layerops — unified installer           │
   │                                                 │
   └─────────────────────────────────────────────────┘
EOF
  printf "${RST}\n"
  printf "  ${DIM}Version: %s${RST}\n" "$LAYEROPS_VERSION"
  printf "  ${DIM}Repository: github.com/%s${RST}\n\n" "$LAYEROPS_REPO"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Usage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --skip-deps       Install only layerops, skip dependency installation
  --deps-only       Install only the dependencies, not layerops itself
  --uninstall       Remove layerops from $INSTALL_DIR (deps are left intact)
  --install-dir <d> Install directory (default: $INSTALL_DIR)
  --version <v>     layerops version to install (default: $LAYEROPS_VERSION)
  -v, --verbose     Show verbose installation output (default: silent)
  -y, --yes         Non-interactive mode — assume yes to all prompts
  -h, --help        Show this help

Environment Variables:
  INSTALL_DIR         Override install directory
  LAYEROPS_VERSION    Override version to install
  NO_COLOR            Disable colored output

Examples:
  # Install everything (layerops + all deps)
  curl -sSL https://raw.githubusercontent.com/$LAYEROPS_REPO/main/scripts/install.sh | bash

  # Install to a custom directory
  curl -sSL ... | bash -s -- --install-dir ~/.local/bin

  # Install only dependencies (useful for CI base images)
  curl -sSL ... | bash -s -- --deps-only

  # Uninstall layerops
  curl -sSL ... | bash -s -- --uninstall
EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argument Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-deps)    SKIP_DEPS=1; shift ;;
      --deps-only)    DEPS_ONLY=1; shift ;;
      --uninstall)    UNINSTALL=1; shift ;;
      --install-dir)  [[ $# -ge 2 ]] || die "--install-dir requires a value"; INSTALL_DIR="$2"; shift 2 ;;
      --version)      [[ $# -ge 2 ]] || die "--version requires a value"; LAYEROPS_VERSION="$2"; shift 2 ;;
      -v|--verbose)   VERBOSE=1; shift ;;
      -y|--yes)       YES_MODE=1; shift ;;
      -h|--help)      usage; exit 0 ;;
      *)              die "Unknown option: $1 (try --help)" ;;
    esac
  done

  if [[ $SKIP_DEPS -eq 1 && $DEPS_ONLY -eq 1 ]]; then
    die "--skip-deps and --deps-only are mutually exclusive"
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS / Architecture Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OS=""
ARCH=""
PKG_MGR=""

detect_os() {
  local kernel arch
  kernel="$(uname -s)"
  arch="$(uname -m)"

  case "$kernel" in
    Darwin)  OS="darwin" ;;
    Linux)   OS="linux" ;;
    *)       die "Unsupported OS: $kernel (only macOS and Linux are supported)" ;;
  esac

  case "$arch" in
    x86_64|amd64)   ARCH="amd64" ;;
    arm64|aarch64)   ARCH="arm64" ;;
    armv7*)          ARCH="armv7" ;;
    *)               die "Unsupported architecture: $arch" ;;
  esac

  info "Detected: ${BOLD}${OS}/${ARCH}${RST}"
}

detect_pkg_manager() {
  if [[ "$OS" == "darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
      PKG_MGR="brew"
    else
      step "Installing Homebrew (required for macOS dependencies)"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Source brew shellenv for Apple Silicon
      if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      PKG_MGR="brew"
    fi
  else
    # Linux — detect package manager
    if command -v apt-get >/dev/null 2>&1; then
      PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
      PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then
      PKG_MGR="yum"
    elif command -v apk >/dev/null 2>&1; then
      PKG_MGR="apk"
    else
      PKG_MGR="unknown"
      warn "No recognised package manager found (apt/dnf/yum/apk)"
    fi
  fi
  substep "Package manager: ${BOLD}${PKG_MGR}${RST}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Privilege & Command Helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ensure_sudo() {
  if [[ "$OS" == "linux" ]] && [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      substep "Administrative privileges required (sudo)..."
      sudo -v || die "Sudo authorization failed"
    fi
  fi
}

maybe_sudo() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Need root privileges. Please run as root or install sudo."
  fi
}

# Utility: run brew safely (Homebrew refuses to run directly as root)
brew_cmd() {
  if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
    sudo -u "$SUDO_USER" brew "$@"
  else
    brew "$@"
  fi
}

# Utility: check a command exists
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Utility: download a URL to a file (curl preferred, wget fallback)
download() {
  local url="$1" dest="$2"
  if has_cmd curl; then
    curl -fsSL "$url" -o "$dest"
  elif has_cmd wget; then
    wget -q "$url" -O "$dest"
  else
    die "Neither curl nor wget found. Please install one and retry."
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install: jq
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
install_jq() {
  step "jq (JSON processor)"

  if has_cmd jq; then
    local ver
    ver="$(jq --version 2>/dev/null || echo 'unknown')"
    ok "Already installed: ${ver}"
    return 0
  fi

  substep "Installing jq..."
  case "$PKG_MGR" in
    brew)
      HOMEBREW_NO_AUTO_UPDATE=1 run_cmd brew_cmd install -q jq
      ;;
    apt)
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq || true
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 jq
      ;;
    dnf)  run_cmd maybe_sudo dnf install -y -q jq ;;
    yum)  run_cmd maybe_sudo yum install -y -q jq ;;
    apk)  run_cmd maybe_sudo apk add --no-cache -q jq ;;
    *)
      # Direct binary download as fallback
      substep "Downloading jq binary from GitHub..."
      local jq_os jq_arch
      jq_os="$OS"
      if [[ "$OS" == "darwin" ]]; then jq_os="macos"; fi
      jq_arch="$ARCH"
      if [[ "$ARCH" == "amd64" ]]; then jq_arch="amd64"; fi
      if [[ "$ARCH" == "arm64" ]]; then jq_arch="arm64"; fi
      local jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-${jq_os}-${jq_arch}"
      local tmp_jq
      tmp_jq="$(mktemp)"
      download "$jq_url" "$tmp_jq"
      chmod +x "$tmp_jq"
      run_cmd maybe_sudo install -m 755 "$tmp_jq" "${INSTALL_DIR}/jq"
      rm -f "$tmp_jq"
      ;;
  esac

  if has_cmd jq; then
    ok "Installed: $(jq --version 2>/dev/null)"
  else
    fail "jq installation failed (see log: ${INSTALL_LOG})"
    return 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install: Trivy
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
install_trivy() {
  step "Trivy (vulnerability scanner)"

  if has_cmd trivy; then
    local ver
    ver="$(trivy version --format json 2>/dev/null | jq -r '.Version // empty' 2>/dev/null || trivy --version 2>/dev/null | head -1 || echo 'unknown')"
    ok "Already installed: ${ver}"
    return 0
  fi

  substep "Installing Trivy..."
  case "$PKG_MGR" in
    brew)
      HOMEBREW_NO_AUTO_UPDATE=1 run_cmd brew_cmd install -q trivy
      ;;
    apt)
      # Official Trivy install via apt repository
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq || true
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 wget apt-transport-https gnupg
      if [[ "$VERBOSE" -eq 1 ]]; then
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | maybe_sudo gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg 2>&1 | tee -a "$INSTALL_LOG"
        echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | maybe_sudo tee /etc/apt/sources.list.d/trivy.list | tee -a "$INSTALL_LOG"
      else
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | maybe_sudo gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg >> "$INSTALL_LOG" 2>&1
        echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | maybe_sudo tee /etc/apt/sources.list.d/trivy.list >> "$INSTALL_LOG" 2>&1
      fi
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq || true
      run_cmd maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 trivy
      ;;
    dnf|yum)
      # Official Trivy RPM repository
      cat <<'REPO' | maybe_sudo tee /etc/yum.repos.d/trivy.repo >> "$INSTALL_LOG" 2>&1
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=0
enabled=1
REPO
      run_cmd maybe_sudo "${PKG_MGR}" install -y -q trivy
      ;;
    *)
      # Fallback: official install script
      substep "Using official Trivy install script..."
      if [[ "$VERBOSE" -eq 1 ]]; then
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${INSTALL_DIR}" 2>&1 | tee -a "$INSTALL_LOG"
      else
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${INSTALL_DIR}" >> "$INSTALL_LOG" 2>&1
      fi
      ;;
  esac

  if ! has_cmd trivy; then
    substep "Trying official Trivy install script fallback..."
    if [[ "$VERBOSE" -eq 1 ]]; then
      curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${INSTALL_DIR}" 2>&1 | tee -a "$INSTALL_LOG" || true
    else
      curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${INSTALL_DIR}" >> "$INSTALL_LOG" 2>&1 || true
    fi
  fi

  if has_cmd trivy; then
    ok "Installed: $(trivy --version 2>/dev/null | head -1)"
  else
    fail "Trivy installation failed (see log: ${INSTALL_LOG})"
    return 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install: Copacetic (copa)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
install_copa() {
  step "Copacetic — copa (OS package patcher)"

  if has_cmd copa; then
    local ver
    ver="$(copa --version 2>/dev/null || echo 'unknown')"
    ok "Already installed: ${ver}"
    return 0
  fi

  substep "Installing copa..."
  case "$PKG_MGR" in
    brew)
      HOMEBREW_NO_AUTO_UPDATE=1 run_cmd brew_cmd install -q copa
      ;;
    *)
      # Download copa binary from GitHub releases
      substep "Downloading copa from GitHub releases..."
      local copa_version copa_url tmp_dir
      # Get latest copa release version
      copa_version="$(curl -fsSL "https://api.github.com/repos/project-copacetic/copacetic/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')"
      if [[ -z "$copa_version" ]]; then
        die "Could not determine latest copa version"
      fi

      local copa_ver_num="${copa_version#v}"
      local copa_os copa_arch
      copa_os="$OS"
      copa_arch="$ARCH"

      copa_url="https://github.com/project-copacetic/copacetic/releases/download/${copa_version}/copa_${copa_ver_num}_${copa_os}_${copa_arch}.tar.gz"

      tmp_dir="$(mktemp -d)"
      trap "rm -rf '$tmp_dir'" RETURN

      download "$copa_url" "${tmp_dir}/copa.tar.gz"
      run_cmd tar -xzf "${tmp_dir}/copa.tar.gz" -C "$tmp_dir"
      run_cmd maybe_sudo install -m 755 "${tmp_dir}/copa" "${INSTALL_DIR}/copa"
      rm -rf "$tmp_dir"
      trap - RETURN
      ;;
  esac

  if has_cmd copa; then
    ok "Installed: $(copa --version 2>/dev/null)"
  else
    fail "copa installation failed (see log: ${INSTALL_LOG})"
    return 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install: Docker
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
install_docker() {
  step "Docker (container runtime)"

  if has_cmd docker; then
    local ver
    ver="$(docker --version 2>/dev/null || echo 'unknown')"
    ok "Already installed: ${ver}"
    return 0
  fi

  substep "Installing Docker..."
  case "$OS" in
    darwin)
      if [[ "$PKG_MGR" == "brew" ]]; then
        substep "Installing Docker Desktop via Homebrew Cask..."
        HOMEBREW_NO_AUTO_UPDATE=1 run_cmd brew_cmd install -q --cask docker
        info "Docker Desktop installed. Please launch it from Applications to start the daemon."
        info "Waiting for Docker Desktop to initialise..."
        # Open Docker.app to start the daemon
        open -a Docker 2>/dev/null || true
      else
        die "Cannot install Docker on macOS without Homebrew. Please install Docker Desktop manually: https://docs.docker.com/desktop/install/mac-install/"
      fi
      ;;
    linux)
      substep "Installing Docker Engine via get.docker.com..."
      if [[ "$VERBOSE" -eq 1 ]]; then
        curl -fsSL https://get.docker.com | maybe_sudo sh 2>&1 | tee -a "$INSTALL_LOG"
      else
        curl -fsSL https://get.docker.com | maybe_sudo sh >> "$INSTALL_LOG" 2>&1
      fi
      # Start and enable Docker
      if has_cmd systemctl; then
        run_cmd maybe_sudo systemctl start docker
        run_cmd maybe_sudo systemctl enable docker
      fi
      # Add current user to docker group (avoids needing sudo for docker commands)
      if [[ $EUID -ne 0 ]] && has_cmd usermod; then
        run_cmd maybe_sudo usermod -aG docker "$USER"
        warn "Added $USER to docker group. You may need to log out and back in for this to take effect."
      fi
      ;;
  esac

  if has_cmd docker; then
    ok "Installed: $(docker --version 2>/dev/null)"
  else
    fail "Docker installation failed (see log: ${INSTALL_LOG})"
    return 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Wait for Docker Daemon
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
wait_for_docker() {
  step "Docker daemon readiness"

  if ! has_cmd docker; then
    warn "Docker command not found — skipping daemon check"
    return 1
  fi

  local max_wait=60
  local waited=0
  local interval=3

  if docker info >/dev/null 2>&1; then
    ok "Docker daemon is running"
    return 0
  fi

  substep "Waiting up to ${max_wait}s for Docker daemon to start..."

  while [[ $waited -lt $max_wait ]]; do
    if docker info >/dev/null 2>&1; then
      ok "Docker daemon is ready (waited ${waited}s)"
      return 0
    fi
    sleep "$interval"
    waited=$((waited + interval))
    substep "  ... ${waited}s elapsed"
  done

  warn "Docker daemon did not respond after ${max_wait}s"
  if [[ "$OS" == "darwin" ]]; then
    warn "Please open Docker Desktop from Applications and re-run this script"
  else
    warn "Try: sudo systemctl start docker"
  fi
  return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup: BuildKit (moby/buildkit container)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_buildkit() {
  step "BuildKit (moby/buildkit container)"

  if ! has_cmd docker; then
    warn "Docker not available — skipping BuildKit setup"
    return 1
  fi

  if ! docker info >/dev/null 2>&1; then
    warn "Docker daemon not running — skipping BuildKit setup"
    return 1
  fi

  # Check if buildkitd container already exists
  local state
  state="$(docker inspect --format '{{.State.Status}}' buildkitd 2>/dev/null || echo 'not_found')"

  case "$state" in
    running)
      ok "BuildKit container 'buildkitd' is already running"
      return 0
      ;;
    exited|created|paused)
      substep "BuildKit container exists but is ${state} — starting it..."
      run_cmd docker start buildkitd
      if docker inspect --format '{{.State.Status}}' buildkitd 2>/dev/null | grep -q "running"; then
        ok "BuildKit container 'buildkitd' started"
      else
        fail "Could not start existing buildkitd container (see log: ${INSTALL_LOG})"
        return 1
      fi
      ;;
    *)
      substep "Pulling moby/buildkit image..."
      run_cmd docker pull moby/buildkit

      substep "Starting BuildKit container..."
      run_cmd docker run -d \
        --name buildkitd \
        --privileged \
        moby/buildkit

      # Verify it started
      sleep 2
      if docker inspect --format '{{.State.Status}}' buildkitd 2>/dev/null | grep -q "running"; then
        ok "BuildKit container 'buildkitd' is running"
      else
        fail "BuildKit container failed to start (see log: ${INSTALL_LOG})"
        return 1
      fi
      ;;
  esac
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install: layerops
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
install_layerops() {
  step "layerops ${LAYEROPS_VERSION}"

  local target="${INSTALL_DIR}/layerops"

  # Check if already installed at the desired version
  if [[ -f "$target" ]] && [[ -x "$target" ]]; then
    local cur_ver
    cur_ver="$("$target" --version 2>/dev/null | awk '{print $NF}' || echo '')"
    if [[ "$cur_ver" == "$LAYEROPS_VERSION" ]]; then
      ok "Already installed: layerops ${cur_ver} at ${target}"
      return 0
    elif [[ -n "$cur_ver" ]]; then
      substep "Upgrading from ${cur_ver} to ${LAYEROPS_VERSION}..."
    fi
  fi

  substep "Downloading layerops ${LAYEROPS_VERSION}..."
  local raw_url="https://raw.githubusercontent.com/${LAYEROPS_REPO}/${LAYEROPS_VERSION}/layerops"
  local tmp_script
  tmp_script="$(mktemp)"

  if ! download "$raw_url" "$tmp_script"; then
    # Fallback: try main branch
    warn "Could not download from tag ${LAYEROPS_VERSION}, trying main branch..."
    raw_url="https://raw.githubusercontent.com/${LAYEROPS_REPO}/main/layerops"
    download "$raw_url" "$tmp_script" || die "Failed to download layerops"
  fi

  # Validate it looks like a shell script
  if ! head -1 "$tmp_script" | grep -q '^#!/'; then
    rm -f "$tmp_script"
    die "Downloaded file does not appear to be a valid script"
  fi

  chmod +x "$tmp_script"

  # Ensure target directory exists
  if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
    run_cmd maybe_sudo mkdir -p "$INSTALL_DIR"
  fi

  # Install to target directory
  local installed=0
  if [[ -w "$INSTALL_DIR" ]]; then
    if mv "$tmp_script" "$target" 2>/dev/null; then
      chmod 755 "$target"
      installed=1
    fi
  fi

  if [[ $installed -eq 0 ]]; then
    substep "Installing to ${target} (requires sudo)..."
    if run_cmd maybe_sudo install -m 755 "$tmp_script" "$target"; then
      installed=1
    fi
    rm -f "$tmp_script"
  fi

  if [[ $installed -eq 1 ]] && [[ -x "$target" ]]; then
    ok "Installed: layerops ${LAYEROPS_VERSION} → ${target}"
    return 0
  else
    fail "Failed to install layerops to ${target} (see log: ${INSTALL_LOG})"
    info "Tip: Run with --install-dir ~/.local/bin to install without sudo"
    return 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Uninstall: layerops
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
do_uninstall() {
  step "Uninstalling layerops"

  local target="${INSTALL_DIR}/layerops"
  if [[ ! -f "$target" ]]; then
    warn "layerops not found at ${target} — nothing to remove"
    return 0
  fi

  if [[ -w "$target" ]]; then
    rm -f "$target"
  else
    run_cmd maybe_sudo rm -f "$target"
  fi

  ok "Removed: ${target}"
  info "Dependencies (jq, trivy, copa, docker) were left intact."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY_INSTALLED=()
SUMMARY_SKIPPED=()
SUMMARY_FAILED=()

track_result() {
  local name="$1" result="$2"
  case "$result" in
    ok)      SUMMARY_INSTALLED+=("$name") ;;
    skip)    SUMMARY_SKIPPED+=("$name") ;;
    fail)    SUMMARY_FAILED+=("$name") ;;
  esac
}

print_summary() {
  printf "\n"
  printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
  printf "${BOLD}  Installation Summary${RST}\n"
  printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n\n"

  # Gather live status for each component
  local components=("jq" "trivy" "copa" "docker" "buildkitd" "layerops")
  for comp in "${components[@]}"; do
    local status_icon version_str
    case "$comp" in
      jq)
        if has_cmd jq; then
          status_icon="${GREEN}✅${RST}"
          version_str="$(jq --version 2>/dev/null || echo '')"
        else
          status_icon="${RED}❌${RST}"
          version_str="not installed"
        fi
        ;;
      trivy)
        if has_cmd trivy; then
          status_icon="${GREEN}✅${RST}"
          version_str="$(trivy --version 2>/dev/null | head -1 || echo '')"
        else
          status_icon="${RED}❌${RST}"
          version_str="not installed"
        fi
        ;;
      copa)
        if has_cmd copa; then
          status_icon="${GREEN}✅${RST}"
          version_str="$(copa --version 2>/dev/null || echo '')"
        else
          status_icon="${RED}❌${RST}"
          version_str="not installed"
        fi
        ;;
      docker)
        if has_cmd docker; then
          status_icon="${GREEN}✅${RST}"
          version_str="$(docker --version 2>/dev/null || echo '')"
          if ! docker info >/dev/null 2>&1; then
            status_icon="${YELLOW}⚠️${RST}"
            version_str="${version_str} (daemon not running)"
          fi
        else
          status_icon="${RED}❌${RST}"
          version_str="not installed"
        fi
        ;;
      buildkitd)
        if has_cmd docker && docker info >/dev/null 2>&1; then
          local bk_state
          bk_state="$(docker inspect --format '{{.State.Status}}' buildkitd 2>/dev/null || echo 'not_found')"
          if [[ "$bk_state" == "running" ]]; then
            status_icon="${GREEN}✅${RST}"
            version_str="container running"
          elif [[ "$bk_state" == "not_found" ]]; then
            status_icon="${RED}❌${RST}"
            version_str="container not found"
          else
            status_icon="${YELLOW}⚠️${RST}"
            version_str="container ${bk_state}"
          fi
        else
          status_icon="${DIM}—${RST}"
          version_str="requires docker"
        fi
        ;;
      layerops)
        if has_cmd layerops; then
          status_icon="${GREEN}✅${RST}"
          version_str="$(layerops --version 2>/dev/null || echo "${LAYEROPS_VERSION}")"
        elif [[ -x "${INSTALL_DIR}/layerops" ]]; then
          status_icon="${GREEN}✅${RST}"
          version_str="${LAYEROPS_VERSION} (${INSTALL_DIR}/layerops)"
        else
          status_icon="${RED}❌${RST}"
          version_str="not installed"
        fi
        ;;
    esac
    printf "  %b  %-12s %s\n" "$status_icon" "$comp" "$version_str"
  done

  printf "\n"

  if [[ ${#SUMMARY_FAILED[@]} -gt 0 ]]; then
    printf "  ${YELLOW}Some components had issues. Check the installation log:${RST}\n"
    printf "    ${WHITE}%s${RST}\n" "$INSTALL_LOG"
    printf "  ${YELLOW}Run 'layerops --doctor' to diagnose.${RST}\n\n"
  else
    printf "  ${DIM}Installation log: %s${RST}\n\n" "$INSTALL_LOG"
  fi

  printf "  ${DIM}Get started:${RST}\n"
  printf "    ${WHITE}layerops --image nginx:latest${RST}\n"
  printf "    ${WHITE}layerops --image nginx:latest --patch --verify${RST}\n"
  printf "    ${WHITE}layerops --doctor${RST}  ${DIM}# check all dependencies${RST}\n\n"

  printf "  ${DIM}Documentation: https://github.com/%s${RST}\n" "$LAYEROPS_REPO"
  printf "  ${DIM}Report issues: https://github.com/%s/issues${RST}\n\n" "$LAYEROPS_REPO"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
  parse_args "$@"

  banner

  # Preflight: need curl or wget
  if ! has_cmd curl && ! has_cmd wget; then
    die "Either curl or wget is required to download packages. Please install one and retry."
  fi

  # Uninstall mode
  if [[ $UNINSTALL -eq 1 ]]; then
    do_uninstall
    exit 0
  fi

  detect_os

  # Install dependencies
  if [[ $SKIP_DEPS -eq 0 ]]; then
    detect_pkg_manager
    ensure_sudo

    # Each install function is fail-safe — a failure is tracked but doesn't
    # abort the script, so the user gets as much installed as possible.
    install_jq     && track_result "jq" "ok"     || track_result "jq" "fail"
    install_trivy  && track_result "trivy" "ok"   || track_result "trivy" "fail"
    install_copa   && track_result "copa" "ok"    || track_result "copa" "fail"
    install_docker && track_result "docker" "ok"  || track_result "docker" "fail"

    if wait_for_docker; then
      setup_buildkit && track_result "buildkit" "ok" || track_result "buildkit" "fail"
    else
      track_result "buildkit" "fail"
    fi
  fi

  # Install layerops itself
  if [[ $DEPS_ONLY -eq 0 ]]; then
    install_layerops && track_result "layerops" "ok" || track_result "layerops" "fail"
  fi

  print_summary
}

main "$@"
