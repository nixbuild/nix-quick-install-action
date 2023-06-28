#!/usr/bin/env bash

set -eu
set -o pipefail

NIX_CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"

declare nix_conf
tmp="$(mktemp)"

flake_file=${flake_file:="$tmp"}
flake_url=${flake_url:="github:$OWNER_AND_REPO/$SHA"}

# only fetch if not (locally) defined (e.g. for testing)
if [ "$flake_file" = "$tmp" ]; then
  set -x
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$OWNER_AND_REPO/contents/flake.nix?ref=$SHA" |
    jq -r '.content|gsub("[\n\t]"; "")|@base64d' >"$flake_file"
  set +x
fi

nix_conf="$(mktemp -d)/nix.conf"
NIX_CONFIG=$(nix --experimental-features "nix-command" eval --raw --impure --expr '(import '"$flake_file"').nixConfig or {}' --apply "$(<"${BASH_SOURCE[0]%/*}/nix_config.nix")" | tee "$nix_conf")

echo >> $nix_conf
echo "accept-flake-config = true" >> $nix_conf

# make sure behaviour between old and new style commands remains aligned
if [[ ! -z "$NIX_CONFIG" ]]; then
    echo >> $nix_conf
    echo "experimental-features = nix-command flakes" >> $nix_conf
fi

NIX_USER_CONF_FILES="$nix_conf:$NIX_CONF_FILE:${NIX_USER_CONF_FILES:-}"

echo "NIX_USER_CONF_FILES=$NIX_USER_CONF_FILES" >> $GITHUB_ENV
