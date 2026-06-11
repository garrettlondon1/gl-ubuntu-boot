#!/bin/bash
#
# gl-ubuntu-boot — Bootstrap a fresh Ubuntu 24.04+ machine
#
# This script:
#   1. Installs git + gh CLI
#   2. Authenticates with GitHub (gh auth login)
#   3. Clones the private gl-ubuntu-dev repo
#   4. Runs setup.sh
#
# Usage (fresh machine, no git required):
#   curl -sL https://raw.githubusercontent.com/garrettlondon1/gl-ubuntu-boot/main/boot.sh | bash
#

set -e

echo '
   ┌─────────────────────────────────────┐
   │  gl-ubuntu-boot                     │
   │  Fresh Ubuntu 24.04+ Bootstrap      │
   └─────────────────────────────────────┘
'

# ─── Install git + gh CLI ─────────────────────────────────────────────────────

echo "▶ Installing git and GitHub CLI..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl > /dev/null

# Install gh CLI (official)
if ! command -v gh &>/dev/null; then
  (type -p wget >/dev/null || (sudo apt-get update && sudo apt-get install wget -y -qq)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null \
    && sudo apt-get update -qq \
    && sudo apt-get install gh -y -qq > /dev/null
fi
echo "  ✓ gh $(gh --version | head -1)"

# ─── GitHub Authentication ────────────────────────────────────────────────────

echo ""
echo "▶ Authenticating with GitHub..."
echo "  You'll need to sign in to clone the private repo."
echo ""

if ! gh auth status &>/dev/null; then
  gh auth login --web -h github.com
fi
echo "  ✓ Authenticated as $(gh api user --jq .login)"

# ─── Clone private repo ──────────────────────────────────────────────────────

echo ""
echo "▶ Cloning gl-ubuntu-dev..."
rm -rf ~/.local/share/omakub
gh repo clone garrettlondon1/gl-ubuntu-dev ~/.local/share/omakub

# ─── Import Microsoft GPG key ─────────────────────────────────────────────────
# Required for Ubuntu 26.04+ where apt may not yet have the Microsoft signing key

echo ""
echo "▶ Importing Microsoft package signing key..."
MICROSOFT_KEY_FINGERPRINT="EE4D7792F748182B"
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
# Verify the expected key fingerprint is present
if ! gpg --no-default-keyring --keyring /etc/apt/trusted.gpg.d/microsoft.gpg \
       --fingerprint 2>/dev/null | grep -qi "${MICROSOFT_KEY_FINGERPRINT}"; then
  echo "  ✗ ERROR: Microsoft GPG key fingerprint ${MICROSOFT_KEY_FINGERPRINT} not found — aborting."
  exit 1
fi
echo "  ✓ Microsoft GPG key imported and verified (${MICROSOFT_KEY_FINGERPRINT})"

# ─── Run setup ────────────────────────────────────────────────────────────────

echo ""
echo "▶ Running setup.sh..."
echo ""
source ~/.local/share/omakub/setup.sh
