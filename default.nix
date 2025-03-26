let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

let
  inherit (pkgs.lib) listToAttrs nameValuePair replaceStrings;

  makeStoreArchive = pkgs.callPackage ./nix/make-store-archive.nix { };

  mkLixSet =
    f: lixen: system:
    listToAttrs (
      map (lix: nameValuePair "v${replaceStrings [ "." ] [ "_" ] lix.version}" (f system lix)) (
        lixen system
      )
    );

  makeVersionSet = mkLixSet (_: lix: lix);
  makeArchiveSet = mkLixSet makeStoreArchive;

  lixVersionsForSystem =
    system:
    let
      # The Lix repo doesn't give us a good way to override nixpkgs when consuming it from outside a flake, so we can
      # do some hacks with the overlay instead.
      lix_2_92 = ((import pins.lix-2_92).overlays.default pkgs pkgs).nix.override {
        # From <https://git.lix.systems/lix-project/nixos-module/pulls/59>:
        # Do not override editline-lix
        # according to the upstream packaging.
        # This was fixed in nixpkgs directly.
        editline-lix = pkgs.editline.overrideAttrs (old: {
          propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pkgs.ncurses ];
        });
      };
    in
    [
      lix_2_92
      pkgs.lixVersions.lix_2_91
      pkgs.lixVersions.lix_2_90
    ];
in
rec {
  inherit pkgs;

  lixVersions = makeVersionSet lixVersionsForSystem builtins.currentSystem;
  lixArchives = makeArchiveSet lixVersionsForSystem builtins.currentSystem;

  combinedArchives = pkgs.symlinkJoin {
    name = "lix-archives";
    paths = builtins.attrValues lixArchives;
  };

  releaseScript = pkgs.callPackage ./nix/release-script.nix rec {
    # TODO: move definitions out of flake
    nixArchives = system: {
      "1.2.3" = {
        inherit system;
        version = "1.2.3";
        impl = "nix";
        fileName = "file";
      };
    };
    lixArchives = system: {
      "4.5.6" = {
        inherit system;
        version = "4.5.6";
        impl = "lix";
        fileName = "file";
      };
    };
    allArchives = pkgs.lib.attrValues ((nixArchives "foobar") // (lixArchives "foobar"));
  };
}
