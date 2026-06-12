#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL="$HOME/.local/share/echo-app-server"
BIN_DIR="$HOME/.local/bin"
NO_NODE_INSTALL="${ECHO_NO_NODE_INSTALL:-0}"

if [[ -t 1 ]]; then
  BOLD='\033[1m'; DIM='\033[2m'; BLUE='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'
else
  BOLD=''; DIM=''; BLUE=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

header() {
  printf '\n%b\n' "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
  printf '%b\n' "${BLUE}║${RESET}                  ${BOLD}Echo App Server Setup${RESET}                     ${BLUE}║${RESET}"
  printf '%b\n' "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
}
step() { printf '\n%b %s\n' "${BLUE}▶${RESET}" "$1"; }
ok() { printf '%b %s\n' "${GREEN}✓${RESET}" "$1"; }
warn() { printf '%b %s\n' "${YELLOW}!${RESET}" "$1"; }
fail() { printf '%b %s\n' "${RED}✗${RESET}" "$1" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
run_sudo() { if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

ask() {
  local prompt="$1" default="$2" value
  read -r -p "$prompt [$default]: " value
  if [[ -z "${value// }" ]]; then printf '%s' "$default"; else printf '%s' "$value"; fi
}

node_major() {
  if have node; then node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0; else echo 0; fi
}

install_node_linux() {
  if [[ "$NO_NODE_INSTALL" == "1" ]]; then fail "Node.js 20+ is required. Install Node.js 22/24 and rerun."; fi
  warn "Node.js 20+ was not found. Attempting automatic install."
  if have apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y ca-certificates curl gnupg
    curl -fsSL https://deb.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo apt-get install -y nodejs
  elif have dnf; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo dnf install -y nodejs
  elif have yum; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | run_sudo bash -
    run_sudo yum install -y nodejs
  elif have pacman; then
    run_sudo pacman -Sy --noconfirm nodejs npm
  elif have zypper; then
    run_sudo zypper install -y nodejs npm
  else
    fail "Unsupported package manager. Install Node.js 22/24 LTS, then rerun."
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
    fail "Node.js install failed or terminal PATH did not refresh. Open a new shell and rerun."
  fi
  ok "Node $(node --version) and npm $(npm --version) ready"
}

copy_project() {
  local from="$1" to="$2"
  mkdir -p "$to"
  if have rsync; then
    rsync -a --delete --exclude node_modules --exclude dist --exclude release --exclude data --exclude .git --exclude .env "$from/" "$to/"
  else
    tar --exclude=node_modules --exclude=dist --exclude=release --exclude=data --exclude=.git --exclude=.env -C "$from" -cf - . | tar -C "$to" -xf -
  fi
}

install_shell_commands() {
  mkdir -p "$BIN_DIR"
  cat > "$BIN_DIR/echo-server" <<EOF
#!/usr/bin/env bash
cd "$INSTALL_DIR"
exec node dist/cli/index.js "\$@"
EOF
  cat > "$BIN_DIR/echo-server-doctor" <<EOF
#!/usr/bin/env bash
cd "$INSTALL_DIR"
exec node dist/cli/index.js doctor "\$@"
EOF
  cat > "$BIN_DIR/echo-server-setup" <<EOF
#!/usr/bin/env bash
cd "$INSTALL_DIR"
exec node dist/cli/index.js setup "\$@"
EOF
  chmod +x "$BIN_DIR/echo-server" "$BIN_DIR/echo-server-doctor" "$BIN_DIR/echo-server-setup"
}

header
step "Preflight checks"
ensure_node

INSTALL_DIR="$(ask "Install Echo App Server to" "$DEFAULT_INSTALL")"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

step "Installing source files"
echo "Target: $INSTALL_DIR"
copy_project "$SOURCE_ROOT" "$INSTALL_DIR"
cd "$INSTALL_DIR"

step "Installing npm dependencies"
npm config delete production --location=project >/dev/null 2>&1 || true
npm config set registry https://registry.npmjs.org/ --location=project >/dev/null
if [[ -x node_modules/.bin/tsc ]]; then
  ok "Dependencies already installed"
else
  npm install --include=dev --no-audit --no-fund --registry https://registry.npmjs.org/
fi

step "Building Echo App Server"
npm run build
[[ -f dist/index.js ]] || fail "Build failed: dist/index.js missing."
[[ -f dist/cli/index.js ]] || fail "Build failed: dist/cli/index.js missing."
ok "Build complete"

step "Running guided setup"
node dist/cli/index.js onboard

step "Installing shell commands"
install_shell_commands
ok "Installed command: $BIN_DIR/echo-server"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  warn "$BIN_DIR is not currently in PATH. Add it to your shell profile, or open a new terminal if it is already configured."
fi

step "Setup complete"
cat <<DONE
${GREEN}✓${RESET} Echo App Server installed.

Next commands:
  echo-server
  echo-server service install
  echo-server service start
  echo-server dashboard
  echo-server update --check
DONE
