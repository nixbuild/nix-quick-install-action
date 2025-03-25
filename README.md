# Lix Quick Install Action

This GitHub Action installs [Lix](https://lix.systems/) in single-user mode, and adds almost no time at all to your workflow's running time.

The Lix installation is deterministic – for a given release of this action the resulting Lix setup will always be identical, no matter when you run the action.

- Supports all Linux and MacOS runners
- Single-user installation (no `nix-daemon`)
- Installs in ≈ 1 second on Linux, ≈ 5 seconds on MacOS
- Allows selecting Lix version via the `nix_version` input
- Allows selecting Nix implementation (either Lix or Nix) via the `nix_implementation` input
- Allows specifying `nix.conf` contents via the `nix_conf` input

## Details

The main motivation behind this action is to install Lix as quickly as possible in your GitHub workflow. If that isn't important, you should probably use the [Lix installer action](https://github.com/samueldr/lix-gha-installer-action) instead, which sets up Lix in multi-user mode (daemon mode) using the official Lix installer. If you want to install Nix instead, check out Cachix's [install-nix-action](https://github.com/cachix/install-nix-action).

To make this action as quick as possible, the installation is minimal: no nix-daemon, no nix channels and no `NIX_PATH`. The nix store (`/nix/store`) is owned by the unprivileged runner user.

The action provides you with a fully working Lix setup, but since no `NIX_PATH` or channels are setup you need to handle this on your own. Flakes is great for this, and works perfectly with this action (see below). [niv](https://github.com/nmattia/niv) should also work fine, but has not been tested yet.

## Inputs

See [action.yml](action.yml) for documentation of the available inputs. The available Lix and Nix versions are listed in the [release notes](https://github.com/canidae-solutions/lix-quick-install-action/releases/latest).

## Usage

### Minimal example

The following workflow installs Lix and then just runs `nix-build --version`:

```yaml
name: Examples
on: push
jobs:
  minimal:
    runs-on: ubuntu-latest
    steps:
      - uses: canidae-solutions/lix-quick-install-action@v1
      - run: nix build --version
      - run: nix build ./examples/flakes-simple
      - name: hello
        run: ./result/bin/hello
```

![action-minimal](examples/action-minimal.png)

### Flakes

These settings are always set by default (except on Nix 2.3):

```conf
experimental-features = nix-command flakes
accept-flake-config = true
```

![action-minimal](examples/action-flakes-simple.png)

You can see the flake definition for the above example in [examples/flakes-simple/flake.nix](examples/flakes-simple/flake.nix).

### Using Cachix

You can use the [Cachix action](https://github.com/marketplace/actions/cachix) together with this action, just make sure you put it after this action in your workflow.

### Using specific Lix versions locally

Locally, you can use this repository's flake to build or run any of the versions of Lix that this action supports. This is very convenient if you quickly need to compare the behavior between different Lix versions.

Build a specific version of Lix like this:

```
$ nix build github:canidae-solutions/lix-quick-install-action#lix-2_92_0

$ ./result/bin/nix --version
nix (Lix, like Nix) 2.92.0
```

With `nix run` you can also directly run Lix like this:

```
$ nix run github:canidae-solutions/lix-quick-install-action#lix-2_92_0 -- --version
nix (Lix, like Nix) 2.92.0
```

List all available Lix versions like this:

```
$ nix flake show --all-systems github:canidae-solutions/lix-quick-install-action/v1
github:canidae-solutions/lix-quick-install-action/c27a9701e6204006a378fe7c97425b5463ca2b09
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
    │   ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_92_0: package 'lix-2.92.0'
    │   ├───nix-2_24_12: package 'nix-2.24.12' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_25_5: package 'nix-2.25.5' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_26_1: package 'nix-2.26.1' - 'The Nix package manager'
    │   ├───nix-2_3_18: package 'nix-2.3.18' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    ├───aarch64-linux
    │   ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_92_0: package 'lix-2.92.0'
    │   ├───nix-2_24_12: package 'nix-2.24.12' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_25_5: package 'nix-2.25.5' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_26_1: package 'nix-2.26.1' - 'The Nix package manager'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    ├───x86_64-darwin
    │   ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_92_0: package 'lix-2.92.0'
    │   ├───nix-2_24_12: package 'nix-2.24.12' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_25_5: package 'nix-2.25.5' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-2_26_1: package 'nix-2.26.1' - 'The Nix package manager'
    │   ├───nix-2_3_18: package 'nix-2.3.18' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───nix-archives: package 'nix-archives'
    │   └───release: package 'release'
    └───x86_64-linux
        ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───lix-2_92_0: package 'lix-2.92.0'
        ├───nix-2_24_12: package 'nix-2.24.12' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───nix-2_25_5: package 'nix-2.25.5' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───nix-2_26_1: package 'nix-2.26.1' - 'The Nix package manager'
        ├───nix-2_3_18: package 'nix-2.3.18' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───nix-archives: package 'nix-archives'
        └───release: package 'release'
```

If you want to make sure that the version of Lix you're trying to build hasn't been removed in the latest revision of `lix-quick-install-action`, you can specify a specific release of `lix-quick-install-action` like this:

```
$ nix build github:canidae-solutions/lix-quick-install-action/v1#lix-2_20_0
```

Note that we've added `/v1` to the flake url above.
