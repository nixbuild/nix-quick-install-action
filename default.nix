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

  lixVersionsForSystem = system: [
    #lix-2_92.packages.${system}.nix
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
