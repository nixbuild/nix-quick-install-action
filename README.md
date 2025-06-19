# Nix Quick Install Action

This GitHub Action installs [Nix](https://nixos.org/nix/) in single-user mode,
and adds almost no time at all to your workflow's running time.

The Nix installation is deterministic &ndash; for a given
release of this action the resulting Nix setup will always be identical, no
matter when you run the action.

* Supports all Linux and MacOS runners

* Currently no support for self-hosted runners

* Single-user installation (no `nix-daemon`)

* Installs in &asymp; 1 second on Linux, &asymp; 5 seconds on MacOS

* Allows selecting Nix version via the `nix_version` input

* Allows specifying `nix.conf` contents via the `nix_conf` input

## Details

The main motivation behind this action is to install Nix as quickly as possible
in your GitHub workflow. If that isn't important, you should probably use the
[Install Nix](https://github.com/marketplace/actions/install-nix) action
instead, which sets up Nix in multi-user mode (daemon mode) using the official
Nix installer.

To make this action as quick as possible, the installation is minimal: no
nix-daemon, no nix channels and no `NIX_PATH`. The nix store (`/nix/store`) is
owned by the unprivileged runner user.

The action provides you with a fully working Nix setup, but since no `NIX_PATH`
or channels are setup you need to handle this on your own. Nix Flakes is great
for this, and works perfectly with this action (see below).
[niv](https://github.com/nmattia/niv) should also work fine, but has not been
tested yet.

## Inputs

See [action.yml](action.yml) for documentation of the available inputs.
The available Nix versions are listed in the [release
notes](https://github.com/nixbuild/nix-quick-install-action/releases/latest).

## Usage

### Minimal example

The following workflow installs Nix and then just runs
`nix-build --version`:

```yaml
name: Examples
on: push
jobs:
  minimal:
    runs-on: ubuntu-latest
    steps:
      - uses: nixbuild/nix-quick-install-action@v30
      - run: nix build --version
      - run: nix build ./examples/flakes-simple
      - name: hello
        run: ./result/bin/hello
```

![action-minimal](examples/action-minimal.png)

### Flakes

For `nix` > `2.13`, these settings are always set by default:

```conf
experimental-features = nix-command flakes
accept-flake-config = true
```

![action-minimal](examples/action-flakes-simple.png)

You can see the flake definition for the above example in
[examples/flakes-simple/flake.nix](examples/flakes-simple/flake.nix).

### Using Cachix

You can use the [Cachix action](https://github.com/marketplace/actions/cachix)
together with this action, just make sure you put it after this action in your
workflow.

### Using specific Nix versions locally

Locally, you can use this repository's Nix flake to build or run any of the
versions of Nix that this action supports. This is very convenient if you
quickly need to compare the behavior between different Nix versions.

Build a specific version of Nix like this (requires you to use a version of Nix
that supports flakes):

```
$ nix build github:nixbuild/nix-quick-install-action#nix-2_26_1

$ ./result/bin/nix --version
nix (Nix) 2.26.1
```

With `nix shell -c` you can also directly run Nix like this:

```
$ nix shell github:nixbuild/nix-quick-install-action#nix-2_26_1 -c nix --version
nix (Nix) 2.26.1
```

List all available Nix versions like this:

```
$ nix flake show --all-systems github:nixbuild/nix-quick-install-action/v30
github:nixbuild/nix-quick-install-action/5bb6a3b3abe66fd09bbf250dce8ada94f856a703?narHash=sha256-7YaZJ5oxsrtMXXrpaqm5pz2Vr3UxdG/Cy2zPIuEuM%2Bc%3D
├───apps
│   ├───aarch64-darwin
│   │   └───release: app
│   ├───aarch64-linux
│   │   └───release: app
│   ├───x86_64-darwin
│   │   └───release: app
│   └───x86_64-linux
│       └───release: app
├───defaultApp
│   ├───aarch64-darwin: app
│   ├───aarch64-linux: app
│   ├───x86_64-darwin: app
│   └───x86_64-linux: app
├───overlays
│   ├───aarch64-darwin: Nixpkgs overlay
│   ├───aarch64-linux: Nixpkgs overlay
│   ├───x86_64-darwin: Nixpkgs overlay
│   └───x86_64-linux: Nixpkgs overlay
└───packages
    ├───aarch64-darwin
    │   ├───nix-2_24_12: package 'nix-2.24.12'
    │   ├───nix-2_25_5: package 'nix-2.25.5'
    │   ├───nix-2_26_1: package 'nix-2.26.1'
    │   ├───nix-2_3_18: package 'nix-2.3.18'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    ├───aarch64-linux
    │   ├───nix-2_24_12: package 'nix-2.24.12'
    │   ├───nix-2_25_5: package 'nix-2.25.5'
    │   ├───nix-2_26_1: package 'nix-2.26.1'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    ├───x86_64-darwin
    │   ├───nix-2_24_12: package 'nix-2.24.12'
    │   ├───nix-2_25_5: package 'nix-2.25.5'
    │   ├───nix-2_26_1: package 'nix-2.26.1'
    │   ├───nix-2_3_18: package 'nix-2.3.18'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    └───x86_64-linux
        ├───nix-2_24_12: package 'nix-2.24.12'
        ├───nix-2_25_5: package 'nix-2.25.5'
        ├───nix-2_26_1: package 'nix-2.26.1'
        ├───nix-2_3_18: package 'nix-2.3.18'
        ├───nix-archives: package 'nix-archives'
        └───release: package 'release'
```

If you want to make sure that the version of Nix you're trying to build hasn't
been removed in the latest revision of `nix-quick-install-action`, you can
specify a specific release of `nix-quick-install-action` like this:

```
$ nix build github:nixbuild/nix-quick-install-action/v29#nix-2_24_9
```

Note that we've added `/v29` to the flake url above.
