#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL="$HOME/.local/share/echo-app-server"
BIN_DIR="$HOME/.local/bin"

ask() {
  local prompt="$1"
  local default="$2"
  read -r -p "$prompt [$default]: " value
  if [[ -z "${value// }" ]]; then printf '%s' "$default"; else printf '%s' "$value"; fi
}

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    major="$(node -p "process.versions.node.split('.')[0]")"
    if [[ "$major" -ge 20 ]]; then
      echo "Node: $(node --version)"
      echo "npm:  $(npm --version)"
      return
    fi
  fi
  echo "Node.js 20+ is required. Install Node.js 24 LTS, then run ./install.sh again."
  exit 1
}

copy_project() {
  local from="$1"
  local to="$2"
  mkdir -p "$to"
  if command -v rsync >/dev/null 2>&1; then
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

echo "============================================================"
echo " Echo App Server - installer"
echo "============================================================"
ensure_node
INSTALL_DIR="$(ask "Install Echo App Server to" "$DEFAULT_INSTALL")"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

echo "Installing source files to: $INSTALL_DIR"
copy_project "$SOURCE_ROOT" "$INSTALL_DIR"
cd "$INSTALL_DIR"

npm config delete production --location=project >/dev/null 2>&1 || true
npm config set registry https://registry.npmjs.org/ --location=project >/dev/null

if [[ -x node_modules/.bin/tsc ]]; then
  echo "Dependencies already installed. Skipping npm install."
else
  echo "Installing dependencies from npm..."
  npm install --include=dev --no-audit --no-fund --registry https://registry.npmjs.org/
fi

echo "Building Echo App Server..."
npm run build
[[ -f dist/index.js ]] || { echo "Build failed: dist/index.js missing."; exit 1; }
[[ -f dist/cli/index.js ]] || { echo "Build failed: dist/cli/index.js missing."; exit 1; }

echo "Running guided setup wizard."
node dist/cli/index.js setup
node dist/cli/index.js doctor

install_shell_commands

echo "============================================================"
echo " Echo App Server installed."
echo " Open a NEW terminal and run: echo-server"
echo " Start server:  echo-server start"
echo " Diagnostics:   echo-server doctor"
echo " Setup wizard:  echo-server setup"
echo " Note: use echo-server, not echo."
echo "============================================================"
