{
  description = "lix-quick-install-action";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  nixConfig = {
    # We set some dummy Nix config here so we can use it for verification in our
    # CI test
    stalled-download-timeout = 333; # default 300
  };

  outputs = { self, nixpkgs }:
  let
    l = nixpkgs.lib // builtins;

    allSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

    forAllSystems = f: l.genAttrs allSystems (system: f (import nixpkgs {
      inherit system;
      overlays = [ (final: prev: prev.prefer-remote-fetch final prev) ];
    }));

  in 
    let

      makeLixArchive = pkgs: lix:
        pkgs.runCommand "make-lix-archive" {
          buildInputs = [ lix pkgs.gnutar pkgs.zstd ];
          closureInfo = pkgs.closureInfo { rootPaths =  [ lix ]; };
          fileName = "lix-${lix.version}-${lix.system}.tar.zstd";
          inherit lix;
        } ''
          mkdir -p root/nix/var/{nix,lix-quick-install-action} "$out"
          ln -s "$lix" root/nix/var/lix-quick-install-action/lix
          cp {"$closureInfo",root/nix/var/lix-quick-install-action}/registration
          tar --create --directory=root --files-from="$closureInfo"/store-paths nix | zstd -o "$out/$fileName"
        '';

      lixVersions = pkgs: l.pipe pkgs.lixVersions [
        l.attrValues
        (l.filter l.isDerivation)
        (l.map (lix: l.nameValuePair lix.version lix))
        l.listToAttrs
      ];

      lixArchives = pkgs: l.mapAttrs (_: makeLixArchive pkgs) (lixVersions pkgs);

      lixPackages = pkgs: l.pipe pkgs [
        lixVersions
        (l.mapAttrs' (vsn: l.nameValuePair "lix-${l.replaceStrings ["."] ["_"] vsn}"))
      ];

    in {
      overlays = forAllSystems (pkgs: _: _: lixPackages pkgs);

      packages = forAllSystems (pkgs: 
      (lixPackages pkgs) // {
        lix-archives = (pkgs.buildEnv {
          name = "lix-archives";
          paths = l.attrValues (lixArchives pkgs);
        }).overrideAttrs {
          preferLocalBuild = false;
          allowSubstitutes = true;

        };
      }
        );
    };
}
