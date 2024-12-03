{
  inputs.nixpkgs.url = "nixpkgs/release-24.05";

  outputs = { self, nixpkgs }:
  let
    forAllSystems = f:
      nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ] (system: nixpkgs.legacyPackages.${system});
  in {
    defaultPackage = forAllSystems (pkgs: pkgs.hello.overrideDerivation (drv: {
      patches = (drv.patches or [ ]) ++ [ ./hello.patch ];
      doCheck = false;
    }));
  };

  nixConfig = {
    allow-import-from-derivation = "true";
  };
}
