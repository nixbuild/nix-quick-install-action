let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

rec {
  inherit pkgs;

  makeStoreArchive = pkgs.callPackage ./nix/make-store-archive.nix { };

  mkLixSet =
    f: lixen: system:
    pkgs.lib.listToAttrs (map (lix: pkgs.lib.nameValuePair lix.version (f system lix)) (lixen system));

  makeVersionSet = mkLixSet (_: lix: lix);
  makeArchiveSet = name: mkLixSet (makeStoreArchive name);

  lixVersionsForSystem = system: [
    #lix-2_92.packages.${system}.nix
    pkgs.lixVersions.lix_2_91
    pkgs.lixVersions.lix_2_90
  ];
  nixVersionsForSystem = (
    system:
    [
      pkgs.nixVersions.nix_2_26
      pkgs.nixVersions.nix_2_25
      pkgs.nixVersions.nix_2_24
    ]
    ++ pkgs.lib.optionals (system != "aarch64-linux") [
      pkgs.nixVersions.minimum
    ]
  );

  lixVersions = makeVersionSet lixVersionsForSystem builtins.currentSystem;
  lixArchives = makeArchiveSet "lix" lixVersionsForSystem builtins.currentSystem;

  nixVersions = makeVersionSet nixVersionsForSystem builtins.currentSystem;
  nixArchives = makeArchiveSet "nix" nixVersionsForSystem builtins.currentSystem;

  combinedArchives = pkgs.symlinkJoin {
    name = "lix-archives";
    paths = pkgs.lib.concatMap builtins.attrValues [
      lixArchives
      nixArchives
    ];
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
