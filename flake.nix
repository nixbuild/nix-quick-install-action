{
  description = "lix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  nixConfig = {
    # We set some dummy Nix config here so we can use it for verification in our
    # CI test
    stalled-download-timeout = 333; # default 300
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
  let allSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
  in flake-utils.lib.eachSystem allSystems (system:

    let

      inherit (nixpkgs) lib;

      preferRemoteBuild = drv: drv.overrideAttrs (_: {
        preferLocalBuild = false;
        allowSubstitutes = true;
      });

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (self: super: super.prefer-remote-fetch self super)
        ];
      };

      makeNixArchive = nix:
        pkgs.runCommand "lix-archive" {
          buildInputs = [ nix pkgs.gnutar pkgs.zstd ];
          closureInfo = pkgs.closureInfo { rootPaths =  [ nix ]; };
          fileName = "lix-${nix.version}-${system}.tar.zstd";
          inherit nix;
        } ''
          mkdir -p root/nix/var/{nix,lix-quick-install-action} "$out"
          ln -s "$nix" root/nix/var/lix-quick-install-action/nix
          cp {"$closureInfo",root/nix/var/lix-quick-install-action}/registration
          tar --create --directory=root --files-from="$closureInfo"/store-paths nix | zstd -o "$out/$fileName"
        '';

      nixVersions = system: lib.listToAttrs (map (nix: lib.nameValuePair nix.version nix) [
        pkgs.lixVersions.latest
        pkgs.lixVersions.lix_2_90
        pkgs.lixVersions.lix_2_91
        pkgs.lixVersions.stable
      ]);

      nixPackages = lib.mapAttrs'
        (v: p: lib.nameValuePair "lix-${lib.replaceStrings ["."] ["_"] v}" p)
        (nixVersions system);

      nixArchives = system: lib.mapAttrs (_: makeNixArchive) (nixVersions system);

      allNixArchives = lib.concatMap (system:
        map (version: {
          inherit system version;
          fileName = "lix-${version}-${system}.tar.zstd";
        }) (lib.attrNames (nixArchives system))
      ) allSystems;

    in {
      overlays = final: prev: nixPackages;

      packages = nixPackages // {
        lix-archives = preferRemoteBuild (pkgs.buildEnv {
          name = "lix-archives";
          paths = lib.attrValues (nixArchives system);
        });
      };
    }
  );
}
