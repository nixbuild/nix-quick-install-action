#!/usr/bin/env bash

set -eu
set -o pipefail

source "${BASH_SOURCE[0]%/*}/vercomp.sh"

case "$(uname -m)" in
  x86_64)
    arch="x86_64"
    ;;
  arm64)
    arch="aarch64"
    ;;
  aarch64)
    arch="aarch64"
    ;;
  *)
    echo >&2 "unsupported architecture: $(uname -m)"
    exit 1
esac

case "$OSTYPE" in
  darwin*)
    sys="$arch-darwin"
    ;;
  linux*)
    sys="$arch-linux"
    ;;
  *)
    echo >& "unsupported OS type: $OSTYPE"
    exit 1
esac

# Enable KVM on Linux so NixOS tests can run quickly.
# Do this early in the process so nix installation detects the KVM feature.
enable_kvm() {
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-install-nix-action-kvm.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
}
if [[ ("$sys" =~ .*-linux) && ("$ENABLE_KVM" == 'true') ]]; then
  enable_kvm && echo 'Enabled KVM' || echo 'KVM is not available'
fi

# Make sure /nix exists and is writeable
if [ -a /nix ]; then
  if ! [ -w /nix ]; then
    echo >&2 "/nix exists but is not writeable, can't set up nix-quick-install-action"
    exit 1
  else
    rm -rf /nix/var/nix-quick-install-action
  fi
elif [[ "$sys" =~ .*-darwin ]]; then
  disk=$(/usr/bin/stat -f "%Sd" /)
  disk=${disk%s[0-9]*}
  sudo $SHELL -euo pipefail << EOF
  echo nix >> /etc/synthetic.conf
  echo -e "run\\tprivate/var/run" >> /etc/synthetic.conf
  /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B &>/dev/null \
    || /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t &>/dev/null \
    || echo "warning: failed to execute apfs.util"
  diskutil apfs addVolume "$disk" APFS nix -mountpoint /nix
  mdutil -i off /nix
  chown $USER /nix
EOF
else
  sudo install -d -o "$USER" /nix
  if [[ "$NIX_ON_TMPFS" == "true" || "$NIX_ON_TMPFS" == "True" || "$NIX_ON_TMPFS" == "TRUE" ]]; then
    sudo mount -t tmpfs -o size=90%,mode=0755,gid="$(id -g)",uid="$(id -u)" tmpfs /nix
  fi
fi

# Fetch and unpack nix archive
if [[ "$sys" =~ .*-darwin ]]; then
  # MacOS tar doesn't have the --skip-old-files, so we use gtar
  tar=gtar
else
  tar=tar
fi
rel="$(head -n1 "$RELEASE_FILE")"
url="${NIX_ARCHIVES_URL:-https://github.com/nixbuild/nix-quick-install-action/releases/download/$rel}/nix-$NIX_VERSION-$sys.tar.zstd"

echo >&2 "Fetching nix archives from $url"
case "$url" in
  file://)
    "$tar" --skip-old-files --strip-components 1 -x -I unzstd -C /nix "${url#file://}"
    ;;
  *)
    curl -sL --retry 3 --retry-connrefused "$url" \
      | "$tar" --skip-old-files --strip-components 1 -x -I unzstd -C /nix
    ;;
esac

# Setup nix.conf
NIX_CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
mkdir -p "$(dirname "$NIX_CONF_FILE")"
touch "$NIX_CONF_FILE"
if [ -n "${NIX_CONF:-}" ]; then
  printenv NIX_CONF > "$NIX_CONF_FILE"
fi

# Setup GitHub access token
if [[ -n "${GITHUB_ACCESS_TOKEN:-}" ]]; then
  echo >>"$NIX_CONF_FILE" \
    "access-tokens = github.com=$GITHUB_ACCESS_TOKEN"
fi

# Setup Flakes
if vergt "$NIX_VERSION" "2.13"; then
  echo >>"$NIX_CONF_FILE" \
    "extra-experimental-features = nix-command flakes"
  echo >>"$NIX_CONF_FILE" \
    "accept-flake-config = true"
fi


# Populate the nix db
echo "Populate the Nix database"

nix="$(readlink /nix/var/nix-quick-install-action/nix)"

attempts=5

for ((i = 0; i < attempts; ++i)); do
  echo "Attempt #$((i + 1))"
    
  "$nix/bin/nix-store" \
    --load-db < /nix/var/nix-quick-install-action/registration && break || true
    
  if (( i == attempts - 1 )); then
    echo "No attempts remain. Exiting."
    exit 1;
  fi
    
  echo >&2 "Retrying Nix DB registration"
  
  sleep 2
done


# Install nix in profile
MANPATH= . "$nix/etc/profile.d/nix.sh"
"$nix/bin/nix-env" -i "$nix"

# Certificate bundle is not detected by nix.sh on macOS.
if [ -z "${NIX_SSL_CERT_FILE:-}" -a -e "/etc/ssl/cert.pem" ]; then
  NIX_SSL_CERT_FILE="/etc/ssl/cert.pem"
fi

# Set env
echo "$HOME/.nix-profile/bin" >> $GITHUB_PATH
echo "NIX_PROFILES=/nix/var/nix/profiles/default $HOME/.nix-profile" >> $GITHUB_ENV
echo "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/$USER" >> $GITHUB_ENV
echo "NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE" >> $GITHUB_ENV
