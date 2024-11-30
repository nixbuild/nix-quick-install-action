{
  inputs = {
    nixpkgs.url = "nixpkgs/release-24.05";
  };

  outputs = { self, nixpkgs }: {

    defaultPackage.x86_64-linux =
      nixpkgs.legacyPackages.x86_64-linux.hello.overrideDerivation (drv: {
        patches = (drv.patches or []) ++ [ ./hello.patch ];
        doCheck = false;
      });

  };

  nixConfig = {
    allow-import-from-derivation = "true";
  };
 
}
