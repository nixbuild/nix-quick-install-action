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
  NIX_CONF_FILE="$(mktemp --tmpdir XXXX_nix.conf)"
  NIX_USER_CONF_FILES="$NIX_CONF_FILE${NIX_USER_CONF_FILES:+:}${NIX_USER_CONF_FILES:-}"
  echo "$NIX_CONF" > "$NIX_CONF_FILE"
  echo "::set-env name=NIX_USER_CONF_FILES::$NIX_USER_CONF_FILES"
fi

# Set PATH
echo "::add-path::/nix/bin"
