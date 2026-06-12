#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${ECHO_INSTALL_REPO:-zmvz11/echo-app-server-linux}"
ASSET_PATTERN="${ECHO_INSTALL_ASSET_PATTERN:-echo-app-server-linux*.zip}"
TAG="${ECHO_INSTALL_TAG:-latest}"
NO_ONBOARD=0
NO_NODE_INSTALL=0

for arg in "$@"; do
  case "$arg" in
    --repo=*) REPO="${arg#--repo=}" ;;
    --asset=*) ASSET_PATTERN="${arg#--asset=}" ;;
    --tag=*) TAG="${arg#--tag=}" ;;
    --no-onboard) NO_ONBOARD=1 ;;
    --no-node-install) NO_NODE_INSTALL=1 ;;
    -h|--help)
      cat <<HELP
Echo App Server one-line installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/zmvz11/echo-app-server-linux/main/scripts/install.sh | bash

Options:
  --repo=owner/repo       GitHub repo to read releases from
  --asset=glob           Release asset pattern, default echo-app-server-linux*.zip
  --tag=v1.0.0           Install a specific release tag instead of latest
  --no-onboard           Download/build only; skip guided setup if supported later
  --no-node-install      Do not attempt automatic Node.js install
HELP
      exit 0
      ;;
  esac
done

if [[ -t 1 ]]; then
  BOLD='\033[1m'; DIM='\033[2m'; BLUE='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'
else
  BOLD=''; DIM=''; BLUE=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

line() { printf '%b\n' "${DIM}────────────────────────────────────────────────────────────${RESET}"; }
header() {
  printf '\n%b\n' "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
  printf '%b\n' "${BLUE}║${RESET}                  ${BOLD}Echo App Server Installer${RESET}                  ${BLUE}║${RESET}"
  printf '%b\n' "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
}
step() { printf '\n%b %s\n' "${BLUE}▶${RESET}" "$1"; }
ok() { printf '%b %s\n' "${GREEN}✓${RESET}" "$1"; }
warn() { printf '%b %s\n' "${YELLOW}!${RESET}" "$1"; }
fail() { printf '%b %s\n' "${RED}✗${RESET}" "$1" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  if ! have "$1"; then fail "Missing required command: $1"; fi
}

run_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

node_major() {
  if have node; then node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0; else echo 0; fi
}

install_node_linux() {
  if [[ "$NO_NODE_INSTALL" -eq 1 ]]; then fail "Node.js 20+ is required. Install Node.js 22/24 and rerun this installer."; fi
  warn "Node.js 20+ was not found. Attempting automatic install."
  if have apt-get; then
    need_cmd curl
    run_sudo apt-get update
    run_sudo apt-get install -y ca-certificates curl gnupg
    curl -fsSL https://deb.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo apt-get install -y nodejs
  elif have dnf; then
    need_cmd curl
    curl -fsSL https://rpm.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo dnf install -y nodejs
  elif have yum; then
    need_cmd curl
    curl -fsSL https://rpm.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo yum install -y nodejs
  elif have pacman; then
    run_sudo pacman -Sy --noconfirm nodejs npm
  elif have zypper; then
    run_sudo zypper install -y nodejs npm
  else
    fail "Could not detect a supported package manager. Install Node.js 22/24 LTS, then rerun."
  fi
}

ensure_node() {
  local major
  major="$(node_major)"
  if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 20 ]] && have npm; then
    ok "Node $(node --version) and npm $(npm --version) detected"
    return
  fi
  install_node_linux
  major="$(node_major)"
  if ! [[ "$major" =~ ^[0-9]+$ ]] || [[ "$major" -lt 20 ]] || ! have npm; then
    fail "Node.js install did not produce Node 20+. Open a new terminal or install Node.js 22/24 manually."
  fi
  ok "Node $(node --version) and npm $(npm --version) ready"
}

download_text() {
  local url="$1"
  if have curl; then
    if [[ -n "${ECHO_GITHUB_TOKEN:-}" ]]; then curl -fsSL -H "Authorization: Bearer $ECHO_GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "User-Agent: EchoInstaller" "$url"; else curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: EchoInstaller" "$url"; fi
  elif have wget; then
    wget -qO- "$url"
  else
    fail "curl or wget is required."
  fi
}

download_file() {
  local url="$1" out="$2"
  if have curl; then curl -fL --progress-bar -o "$out" "$url"; else wget -O "$out" "$url"; fi
}

find_asset_url() {
  local json="$1" pattern="$2"
  if have python3; then
    JSON_TEXT="$json" PATTERN="$pattern" python3 - <<'PYFIND'
import json, os, fnmatch, sys
try:
    data = json.loads(os.environ['JSON_TEXT'])
except Exception as exc:
    print('', end='')
    sys.exit(0)
for asset in data.get('assets', []):
    name = asset.get('name', '')
    if fnmatch.fnmatch(name, os.environ['PATTERN']):
        print(asset.get('browser_download_url', ''))
        break
PYFIND
  else
    printf '%s' "$json" | grep -oE 'https://[^" ]+' | while IFS= read -r url; do
      local name="${url##*/}"
      if [[ "$name" == $pattern ]]; then printf '%s\n' "$url"; break; fi
    done
  fi
}

header
line
printf '%bRepo:%b   %s\n' "$BOLD" "$RESET" "$REPO"
printf '%bAsset:%b  %s\n' "$BOLD" "$RESET" "$ASSET_PATTERN"
printf '%bTag:%b    %s\n' "$BOLD" "$RESET" "$TAG"
line

step "Preflight checks"
need_cmd unzip
if ! have curl && ! have wget; then fail "curl or wget is required."; fi
ensure_node

step "Finding latest Echo App Server release"
if [[ "$TAG" == "latest" ]]; then
  API_URL="https://api.github.com/repos/$REPO/releases/latest"
else
  API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi
RELEASE_JSON="$(download_text "$API_URL")" || fail "Could not read GitHub release: $API_URL"
ASSET_URL="$(find_asset_url "$RELEASE_JSON" "$ASSET_PATTERN")"
if [[ -z "$ASSET_URL" ]]; then
  fail "No release asset matched '$ASSET_PATTERN'. Upload the server zip to GitHub Releases first."
fi
ok "Found release asset: ${ASSET_URL##*/}"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
ZIP_PATH="$TMP_DIR/echo-server.zip"

step "Downloading package"
download_file "$ASSET_URL" "$ZIP_PATH"
ok "Downloaded $(du -h "$ZIP_PATH" | awk '{print $1}')"

step "Extracting package"
unzip -q "$ZIP_PATH" -d "$TMP_DIR/package"
PKG_ROOT="$(find "$TMP_DIR/package" -maxdepth 3 -type f -name package.json -printf '%h\n' | head -n 1)"
if [[ -z "$PKG_ROOT" ]]; then fail "Downloaded package did not contain package.json."; fi
ok "Package root: $PKG_ROOT"

step "Launching Echo guided installer"
cd "$PKG_ROOT"
if [[ -x ./install.sh ]]; then
  ./install.sh
elif [[ -f ./install.sh ]]; then
  bash ./install.sh
else
  fail "Package did not contain install.sh."
fi

step "Install complete"
cat <<DONE
${GREEN}✓${RESET} Echo App Server was installed.

Next commands:
  echo-server
  echo-server onboard
  echo-server service install
  echo-server service start
  echo-server dashboard
DONE
