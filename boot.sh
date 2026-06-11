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

# ─── Import Microsoft GPG key ─────────────────────────────────────────────────
# Must run before apt-get update — the system may already have Microsoft apt
# sources configured (e.g. from a previous VS Code install).  Without this key
# apt-get update fails with a "not signed" error and the script exits.

echo "▶ Importing Microsoft package signing key..."
# Current Microsoft package signing key full fingerprint (rotated from the
# older EE4D7792F748182B short ID). See https://packages.microsoft.com/keys/
MICROSOFT_KEY_FINGERPRINT="BC528686B50D79E339D3721CEB3E94ADBE1229CF"
MICROSOFT_KEY_FINGERPRINT_LEGACY="EB3E94ADBE1229CF"

sudo install -d -m 0755 /etc/apt/trusted.gpg.d /usr/share/keyrings /etc/apt/keyrings

# Dearmor once, then install the key at every path a Microsoft-provided
# sources.list.d entry might reference via `signed-by=`. Without this, an
# existing vscode / vscode-insiders / edge / prod source file will fail
# `apt-get update` with "repository ... is not signed" even though the key
# is present in trusted.gpg.d (signed-by overrides the global trust store).
MS_KEY_TMP=$(mktemp)
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor > "$MS_KEY_TMP"

for dest in \
    /etc/apt/trusted.gpg.d/microsoft.gpg \
    /usr/share/keyrings/microsoft.gpg \
    /usr/share/keyrings/microsoft-archive-keyring.gpg \
    /usr/share/keyrings/microsoft-prod.gpg \
    /etc/apt/keyrings/microsoft.gpg ; do
  sudo install -m 0644 "$MS_KEY_TMP" "$dest"
done
rm -f "$MS_KEY_TMP"

# Verify the expected key fingerprint is present. gpg formats the fingerprint
# with spaces between every 4 hex chars, so strip whitespace before matching.
ACTUAL_FPS=$(gpg --no-default-keyring --keyring /etc/apt/trusted.gpg.d/microsoft.gpg \
               --with-colons --fingerprint 2>/dev/null \
             | awk -F: '/^fpr:/ {print $10}')

if echo "$ACTUAL_FPS" | grep -qi "^${MICROSOFT_KEY_FINGERPRINT}$"; then
  echo "  ✓ Microsoft GPG key imported and verified (${MICROSOFT_KEY_FINGERPRINT})"
elif echo "$ACTUAL_FPS" | grep -qi "${MICROSOFT_KEY_FINGERPRINT_LEGACY}$"; then
  echo "  ✓ Microsoft GPG key imported and verified (legacy key)"
else
  echo "  ✗ ERROR: Microsoft GPG key fingerprint did not match expected value."
  echo "    Expected: ${MICROSOFT_KEY_FINGERPRINT}"
  echo "    Found:    ${ACTUAL_FPS:-<none>}"
  exit 1
fi

# ─── Install git + gh CLI ─────────────────────────────────────────────────────

echo ""
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

# ─── Run setup ────────────────────────────────────────────────────────────────

echo ""
echo "▶ Running setup.sh..."
echo ""
source ~/.local/share/omakub/setup.sh
