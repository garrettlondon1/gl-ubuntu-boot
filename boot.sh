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

echo "▶ Importing Microsoft package signing keys..."
# Microsoft rotated their Linux signing key in Spring 2025. Newer repos
# (e.g. packages.microsoft.com/ubuntu/26.04/prod) are signed with the new
# key (short ID EE4D7792F748182B, distributed in microsoft-rolling.asc),
# while older repos still use the legacy key (short ID EB3E94ADBE1229CF,
# distributed in microsoft.asc). Install BOTH so apt-get update succeeds
# regardless of which Microsoft repos are configured.
MS_KEY_NEW_ID="EE4D7792F748182B"
MS_KEY_OLD_ID="EB3E94ADBE1229CF"

sudo install -d -m 0755 /etc/apt/trusted.gpg.d /usr/share/keyrings /etc/apt/keyrings

MS_KEY_TMP=$(mktemp)
{
  curl -fsSL https://packages.microsoft.com/keys/microsoft-rolling.asc \
    || curl -fsSL https://packages.microsoft.com/keys/microsoft-2025.asc
  echo
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc
} | gpg --dearmor > "$MS_KEY_TMP"

# Sanity-check: both expected key IDs must be present in the combined keyring.
FOUND_IDS=$(gpg --no-default-keyring --keyring "$MS_KEY_TMP" \
              --with-colons --fingerprint 2>/dev/null \
            | awk -F: '/^fpr:/ {print $10}')
for id in "$MS_KEY_NEW_ID" "$MS_KEY_OLD_ID"; do
  if ! echo "$FOUND_IDS" | grep -qi "${id}$"; then
    echo "  ✗ ERROR: Microsoft GPG key ${id} not found in downloaded keys."
    echo "    Got: ${FOUND_IDS:-<none>}"
    rm -f "$MS_KEY_TMP"
    exit 1
  fi
done

# Install the combined keyring everywhere a Microsoft sources.list.d entry
# might reference it via signed-by= (or the global trust store).
for dest in \
    /etc/apt/trusted.gpg.d/microsoft.gpg \
    /usr/share/keyrings/microsoft.gpg \
    /usr/share/keyrings/microsoft-archive-keyring.gpg \
    /usr/share/keyrings/microsoft-prod.gpg \
    /etc/apt/keyrings/microsoft.gpg ; do
  sudo install -m 0644 "$MS_KEY_TMP" "$dest"
done
rm -f "$MS_KEY_TMP"
echo "  ✓ Microsoft GPG keys imported (legacy ${MS_KEY_OLD_ID} + rolling ${MS_KEY_NEW_ID})"

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
