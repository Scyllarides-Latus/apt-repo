#!/usr/bin/env bash
# Scyllarides-Latus APT Repository — one-liner installer
# Usage: curl -fsSL https://scyllarides-latus.github.io/apt-repo/setup.sh | sudo bash
set -euo pipefail

KEYRING="/usr/share/keyrings/scyllarides-latus.gpg"
SOURCES="/etc/apt/sources.list.d/scyllarides-latus.list"
REPO_URL="https://scyllarides-latus.github.io/apt-repo"

echo "Installing Scyllarides-Latus APT repository..."

# Install GPG public key
curl -fsSL "${REPO_URL}/gpg.key" | gpg --dearmor -o "${KEYRING}"
chmod 644 "${KEYRING}"

# Detect architecture
ARCH=$(dpkg --print-architecture)

# Add sources list entry
cat > "${SOURCES}" <<EOF
deb [arch=${ARCH} signed-by=${KEYRING}] ${REPO_URL} stable main
EOF

echo "Repository added. Run 'apt update' to refresh package lists."
