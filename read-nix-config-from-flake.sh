#!/usr/bin/env bash

set -eu
set -o pipefail

# Exit early if config loading has not been enabled
[[ "$LOAD_NIXCONFIG" == "true"
|| "$LOAD_NIXCONFIG" == "True"
|| "$LOAD_NIXCONFIG" == "TRUE"
]] || exit 0

source "${BASH_SOURCE[0]%/*}/vercomp.sh"
if verlte "$NIX_VERSION" "2.13"; then
  echo "Do not load flake config on nix version <= 2.13"
  exit 0
fi

NIX_CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"

declare nix_conf
tmp="$(mktemp)"

flake_file=${flake_file:="$tmp"}
flake_url=${flake_url:="github:$OWNER_AND_REPO/$SHA"}

# only fetch if not (locally) defined (e.g. for testing)
if [ "$flake_file" = "$tmp" ]; then
  gh_err="$(mktemp)"
  gh_out="$(mktemp)"
  gh api 2>"$gh_err" >"$gh_out" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$OWNER_AND_REPO/contents/flake.nix?ref=$SHA" || true
  gh_ec=$?
  if [ "$gh_ec" -ne 0 ]; then
    if grep -q "HTTP 404" "$gh_err"; then
      echo >&2 "No flake.nix found, not loading config"
      exit 0
    else
      echo >&2 "Error when fetching flake.nix: ($gh_ec) $(cat "$gh_err")"
      exit 1
    fi
  else
    jq -r '.content|gsub("[\n\t]"; "")|@base64d' "$gh_out" >"$flake_file" || exit 1
  fi
fi

nix_conf="$(mktemp -d)/flake-nixConfig.conf"
NIX_CONFIG=$(nix --experimental-features "nix-command" eval --raw --impure --expr '(import '"$flake_file"').nixConfig or {}' --apply "$(<"${BASH_SOURCE[0]%/*}/nix_config.nix")" | tee "$nix_conf")

NIX_USER_CONF_FILES="$nix_conf:$NIX_CONF_FILE:${NIX_USER_CONF_FILES:-}"

echo "NIX_USER_CONF_FILES=$NIX_USER_CONF_FILES" >> $GITHUB_ENV
