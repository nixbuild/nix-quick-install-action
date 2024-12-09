{
  description = "lix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/970e93b9f82e2a0f3675757eb0bfc73297cc6370";
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
          mkdir -p "$out" root/nix/var/{nix,lix-quick-install-action}
          ln -s $nix root/nix/var/lix-quick-install-action/nix
          cp -t root/nix/var/lix-quick-install-action $closureInfo/registration
          tar -cvT $closureInfo/store-paths -C root nix | zstd -o "$out/$fileName"
        '';

      nixVersions = let
        # XXX(ttlgcc): LTO is broken on x86_64-darwin.  See:
        #  https://github.com/NixOS/nixpkgs/pull/353576
        b_lto = with pkgs.stdenv; lib.mesonBool "b_lto" (!hostPlatform.isStatic && cc.isGNU);
      in system: lib.listToAttrs (map (nix: lib.nameValuePair
        nix.version (nix.overrideAttrs (old: {
          mesonFlags = lib.filter (x: !(lib.hasPrefix "-Db_lto=" x)) old.mesonFlags ++ [ b_lto ];
        }))
      ) (
        [
          pkgs.lixVersions.latest
          pkgs.lixVersions.lix_2_90
          pkgs.lixVersions.lix_2_91
          pkgs.lixVersions.stable
        ]
      ));

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

    in rec {
      defaultApp = apps.release;

      apps.release = {
        type = "app";
        program = lib.getExe packages.release;
      };

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
