# Lix Quick Install Action

This GitHub Action installs [Lix](https://lix.systems/) in single-user mode,
and adds almost no time at all to your workflow's running time.

The Lix installation is deterministic – for a given
release of this action the resulting Lix setup will always be identical, no
matter when you run the action.

- Supports all Linux and MacOS runners

- Single-user installation (no `nix-daemon`)

- Installs in ≈ 1 second on Linux, ≈ 5 seconds on MacOS

- Allows selecting Lix version via the `lix_version` input

- Allows specifying `nix.conf` contents via the `nix_conf` input

## Details

The main motivation behind this action is to install Lix as quickly as possible
in your GitHub workflow.

To make this action as quick as possible, the installation is minimal: no
nix-daemon, no nix channels and no `NIX_PATH`. The nix store (`/nix/store`) is
owned by the unprivileged runner user.

The action provides you with a fully working Lix setup, but since no `NIX_PATH`
or channels are setup you need to handle this on your own. Lix Flakes is great
for this, and works perfectly with this action (see below).

## Inputs

See [action.yml](action.yml) for documentation of the available inputs.
The available Lix versions are listed in the [release
notes](https://github.com/fabrictest/action-lix-quick-install/releases/latest).

## Usage

### Minimal example

The following workflow installs Lix and then just runs
`nix-build --version`:

```yaml
name: Examples
on: push
jobs:
  minimal:
    runs-on: ubuntu-latest
    steps:
      - uses: fabrictest/action-lix-quick-install@v1
      - run: nix build --version
      - run: nix build ./examples/flakes
      - run: ./result/bin/hello
```

![action-minimal](https://github.com/user-attachments/assets/89a6c8bf-5a07-4301-b2fc-43f1aa38fbd3)

### Flakes

These settings are always set by default:

```conf
experimental-features = nix-command flakes
accept-flake-config = true
```

![action-flake](https://github.com/user-attachments/assets/f2fded39-3f20-4e32-9444-21e571fe615c)

You can see the flake definition for the above example in
[examples/flakes/flake.nix](examples/flakes/flake.nix).

### Using Cachix

You can use the [Cachix action](https://github.com/marketplace/actions/cachix)
together with this action, just make sure you put it after this action in your
workflow.

### Using specific Lix versions locally

Locally, you can use this repository's Lix flake to build or run any of the
versions of Lix that this action supports. This is very convenient if you
quickly need to compare the behavior between different Lix versions.

Build a specific version of Lix like this (requires you to use a version of Lix
that supports flakes):

```console
$ nix build github:fabrictest/action-lix-quick-install#lix-2_91_1
$ ./result/bin/nix --version
nix (Lix, like Nix) 2.91.1
```

With `nix shell -c` you can also directly run Nix like this:

```console
$ nix shell github:fabrictest/action-lix-quick-install#lix-2_91_1 -c nix --version
nix (Lix, like Nix) 2.91.1
```

List all available Lix versions like this:

```console
$ nix flake show --all-systems github:fabrictest/action-lix-quick-install/v1
github:fabrictest/action-lix-quick-install/25aff27c252e0c8cdda3264805f7b6bcd92c8718?narHash=sha256-th0CV5CoVJm1GYjr7dk%2BebG/3pQp//vqndKWeo/yreY%3D
git+file:///Users/ttlgcc/fabrictest/action-lix-quick-install
├───apps
│   ├───aarch64-darwin
│   │   └───release: app
│   ├───x86_64-darwin
│   │   └───release: app
│   └───x86_64-linux
│       └───release: app
├───defaultApp
│   ├───aarch64-darwin: app
│   ├───x86_64-darwin: app
│   └───x86_64-linux: app
├───overlays
│   ├───aarch64-darwin: Nixpkgs overlay
│   ├───x86_64-darwin: Nixpkgs overlay
│   └───x86_64-linux: Nixpkgs overlay
└───packages
    ├───aarch64-darwin
    │   ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-archives: package 'lix-archives'
    │   └───release: package 'release'
    ├───x86_64-darwin
    │   ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
    │   ├───lix-archives: package 'lix-archives'
    │   └───release: package 'release'
    └───x86_64-linux
        ├───lix-2_90_0: package 'lix-2.90.0' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───lix-2_91_1: package 'lix-2.91.1' - 'Powerful package manager that makes package management reliable and reproducible'
        ├───lix-archives: package 'lix-archives'
        └───release: package 'release'
```

If you want to make sure that the version of Lix you're trying to build hasn't
been removed in the latest revision of `action-lix-quick-install`, you can
specify a specific release of `action-lix-quick-install` like this:

```console
$ nix build github:fabrictest/action-lix-quick-install/v1#lix-2_91_1
```

Note that we've added `/v1` to the flake url above.
