# gl-ubuntu-boot

Bootstrap a fresh Ubuntu 24.04+ machine with one command. No git or auth required beforehand.

## Usage

```bash
curl -sL https://raw.githubusercontent.com/garrettlondon1/gl-ubuntu-boot/main/boot.sh | bash
```

## What it does

1. Installs `git` and `gh` (GitHub CLI)
2. Runs `gh auth login` — authenticates you via browser device flow
3. Clones the private [gl-ubuntu-dev](https://github.com/garrettlondon1/gl-ubuntu-dev) repo
4. Runs `setup.sh` to configure your entire workstation

## Requirements

- Ubuntu 24.04+ (fresh install)
- Internet connection
- A browser to complete GitHub device-flow login
