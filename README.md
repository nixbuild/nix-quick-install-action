# Nix Quick Install Action

This GitHub Action installs [Nix](https://nixos.org/nix/) in single-user mode.

## Description

To make the action as quick as possible, the installation is minimal: no
nix-daemon, no nix channels and no `NIX_PATH`. The nix store (`/nix/store`) is
owned by the unprivileged runner user. The action has inputs for selecting which
Nix version to use, and to specify `nix.conf` contents.

The action provides you with a fully working Nix setup, but since no `NIX_PATH`
or channels are setup you need to handle this on your own. Nix Flakes is great
for this, and works perfectly with this action (see below).
[niv](https://github.com/nmattia/niv) should also work fine, but has not been
tested yet.

If this action doesn't work out for your use case, you should look at the
[Install Nix](https://github.com/marketplace/actions/install-nix) action.

## Usage

Coming soon

## Inputs

See [action.yml](action.yml) for documentation of the available inputs.
Available Nix versions are listed in the [release
notes](https://github.com/nixbuild/nix-quick-install-action/releases/latest).
