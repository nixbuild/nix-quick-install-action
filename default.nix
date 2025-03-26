let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

rec {
  inherit pkgs;

  makeStoreArchive = (pkgs.callPackage ./nix/make-store-archive.nix { }) builtins.currentSystem;
  makeVersionSet =
    versions: system:
    pkgs.lib.listToAttrs (map (v: pkgs.lib.nameValuePair v.version v) (versions system));
  makeArchiveSet =
    versions: system:
    pkgs.lib.listToAttrs (
      map (v: pkgs.lib.nameValuePair v.version (makeStoreArchive "lix" v)) (versions system)
    );

  lixVersionsForSystem = system: [
    #lix-2_92.packages.${system}.nix
    pkgs.lixVersions.lix_2_91
    pkgs.lixVersions.lix_2_90
  ];

  lixVersions = makeVersionSet lixVersionsForSystem builtins.currentSystem;
  lixArchives = makeArchiveSet lixVersionsForSystem builtins.currentSystem;

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
