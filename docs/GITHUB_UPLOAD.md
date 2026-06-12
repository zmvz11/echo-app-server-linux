# Upload Echo App Server for Linux to GitHub

Create a new GitHub repository named:

```text
echo-app-server-linux
```

When creating the repo, do not add a README, license, or .gitignore. This package already includes them.

Then unzip this package and run these commands inside the extracted `echo-app-server-linux` folder:

```bash
git init
git add .
git commit -m "Initial Echo App Server for Linux release candidate"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/echo-app-server-linux.git
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username or organization name.

## First local test

Terminal:

```bash
./scripts/install-linux.sh
```

## Release packaging

```bash
npm run package:linux
```
## After cloning or downloading

Run the single installer from the repo root: `INSTALL.bat` on Windows or `./install.sh` on Linux. See `docs/INSTALL.md`.

