{
  lib,
  callPackage,
  pkgs,

  editline,
  lixVersions,
  ncurses,
}:

let
  pins = import ../npins;

  inherit (lib) listToAttrs nameValuePair replaceStrings;

  makeStoreArchive = callPackage ./make-store-archive.nix { };

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
        editline-lix = editline.overrideAttrs (old: {
          propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ ncurses ];
        });
      };
    in
    [
      lix_2_92
      lixVersions.lix_2_91
      lixVersions.lix_2_90
    ];
in
rec {
  lixVersionsFor = makeVersionSet lixVersionsForSystem;
  lixArchivesFor = makeArchiveSet lixVersionsForSystem;

  combinedArchivesFor =
    system:
    pkgs.symlinkJoin {
      name = "lix-archives";
      paths = builtins.attrValues (lixArchivesFor system);
    };
}
