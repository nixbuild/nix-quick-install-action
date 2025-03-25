let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

{
  inherit pkgs;

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
