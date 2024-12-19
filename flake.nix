{
  description = "Install Lix on GitHub Actions faster than you can refresh your browser[1]";

  outputs =
    inputs@{
      self,
      std,
      systems,
      ...
    }:
    std.growOn
      {
        inherit inputs;
        systems = import systems;
        cellsFrom = ./nix;
        cellBlocks = [
          (std.blockTypes.devshells "shells")
          (std.blockTypes.nixago "settings")
          (std.blockTypes.installables "packages")
          (std.blockTypes.functions "overlays")
          (std.blockTypes.pkgs "pkgs")
        ];
      }
      {
        packages = std.harvest self [
          "tarballs"
          "packages"
        ];
      }
      {
        devShells = std.harvest self [
          "local"
          "shells"
        ];
      };

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs = {
        systems.follows = "systems";
      };
    };

    nixago = {
      url = "github:nix-community/nixago";
      inputs = {
        nixago-exts.follows = "std/blank";
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
    };

    std = {
      url = "github:divnix/std";
      inputs = {
        devshell.follows = "devshell";
        lib.follows = "nixpkgs";
        nixago.follows = "nixago";
        nixpkgs.follows = "nixpkgs";
      };
    };

    systems = {
      url = "github:nix-systems/default";
    };
  };

  nixConfig = {
    # We set some dummy Nix config here so we can use it for verification in our
    # CI test
    stalled-download-timeout = 333; # default 300
  };
}
