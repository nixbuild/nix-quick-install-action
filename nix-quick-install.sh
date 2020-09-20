#!/usr/bin/env bash

set -eu
set -o pipefail

# Create user-writeable /nix
sudo install -d -o "$USER" /nix

# Fetch and unpack nix
sys="x86_64-linux" # TODO auto detect
rel="$(cat "$RELEASE_FILE")"
url="${NIX_ARCHIVES_URL:-https://github.com/nixbuild/nix-quick-install-action/releases/download/$rel}/nix-$NIX_VERSION-$sys.tar.zstd"

curl -sL --retry 3 --retry-connrefused "$url" | zstdcat | \
  tar --no-overwrite-dir -xC /

# Setup nix.conf
if [ -n "$NIX_CONF" ]; then
  NIX_CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
  mkdir -p "$(dirname "$NIX_CONF_FILE")"
  printenv NIX_CONF > "$NIX_CONF_FILE"
fi

# Set PATH
echo "::add-path::/nix/var/nix/profiles/per-user/$USER/profile/bin"
echo "::add-path::/nix/var/nix/profiles/default/bin"
echo "::add-path::/nix/bin"
