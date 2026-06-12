# Echo App Server — Linux

Clean GitHub-ready package for Echo App Server on Linux.

## One-line install from GitHub

After you publish a GitHub Release with the Linux server zip attached, users can install with:

```bash
curl -fsSL https://raw.githubusercontent.com/zmvz11/echo-app-server-linux/main/scripts/install.sh | bash
```

The one-line installer downloads the latest GitHub Release, checks Node.js, installs the package, launches guided onboarding, and leaves the `echo-server` command available.

## Local install from this repo

Run one installer from the repo root:

```text
./install.sh
```

Do not run old helper scripts. This package intentionally has one obvious local install entry point.

## After install

Open a new terminal and run:

```text
echo-server
```

Server management commands:

```text
echo-server status
echo-server doctor
echo-server setup
echo-server onboard
echo-server service install
echo-server update --check
```

During install, the setup wizard asks for the server port, public IP/hostname, data folder, and first Owner username/password.

## CLI command

Use `echo-server` after install. Do not use `echo`; on Windows that command belongs to the shell.

```bash
echo-server
echo-server setup
echo-server start
echo-server status
echo-server doctor
echo-server users pending
echo-server approve <username>
```

See `COMMANDS.md` for the full command list.

## CLI v4 command center

Echo App Server includes an OpenClaw-inspired CLI command center:

```bash
echo-server
echo-server onboard
echo-server dashboard
echo-server service status
echo-server update --check
```

The GitHub updater uses GitHub Releases, creates backups, preserves `.env` and `data/`, rebuilds the server, and supports rollback.
