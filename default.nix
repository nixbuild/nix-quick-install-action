let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

let
  archives = pkgs.callPackage ./nix/archives.nix { };
in
rec {
  inherit pkgs;

  lixVersions = archives.lixVersionsFor pkgs.system;
  lixArchives = archives.lixArchivesFor pkgs.system;

  combinedArchives = archives.combinedArchivesFor pkgs.system;

  releaseScript = pkgs.callPackage ./nix/release-script.nix {
    inherit (archives) lixArchivesFor;
  };
}
