{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { nixpkgs, systems, ... }:
    let
      forAllSystems =
        f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      defaultPackage = forAllSystems (
        pkgs:
        pkgs.hello.overrideDerivation (drv: {
          patches = (drv.patches or [ ]) ++ [ ./hello.patch ];
          doCheck = false;
        })
      );
    };

  nixConfig = {
    allow-import-from-derivation = "true";
  };
}
