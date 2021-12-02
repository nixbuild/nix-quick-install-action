{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable-small";
    nixpkgs-nix-2_4.url = "nixpkgs/e912008eef096f52f28cf87492830c54ef334eb4";
    nixpkgs-nix-2_3_15.url = "nixpkgs/9bd0be76b2219e8984566340e26a0f85caeb89cd";
    nixpkgs-nix-2_3_14.url = "nixpkgs/314f595ab1cd09a27ad66dd1283344fa5745e473";
    nixpkgs-nix-2_3_12.url = "nixpkgs/edb5ff75f24e95e1ff2a05329e4c051de5eea4f2";
    nixpkgs-nix-2_3_10.url = "nixpkgs/31999436daf18dc4f98559304aa846613dd821bb";
    nixpkgs-nix-2_3_7.url = "nixpkgs/046427570ebe2726a2f21c3b51d84d29c86ebde5";
    nixpkgs-nix-2_2_2.url = "nixpkgs/5399f34ad9481849720d14605ce87b81abe202e9";
    nixpkgs-nix-2_2_2.flake = false;
    nixpkgs-nix-2_1_3.url = "nixpkgs/2c9265c95075170ad210ed5635ecffcd36db6b84";
    nixpkgs-nix-2_1_3.flake = false;
    nixpkgs-nix-2_0_4.url = "nixpkgs/47b85dc5ab8243a653c20d4851a3e6c966877251";
    nixpkgs-nix-2_0_4.flake = false;
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nixpkgs-nix-2_4,
    nixpkgs-nix-2_3_15,
    nixpkgs-nix-2_3_14,
    nixpkgs-nix-2_3_12,
    nixpkgs-nix-2_3_10,
    nixpkgs-nix-2_3_7,
    nixpkgs-nix-2_2_2,
    nixpkgs-nix-2_1_3,
    nixpkgs-nix-2_0_4
  }:
  let allSystems = ["x86_64-linux" "x86_64-darwin"];
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
        pkgs.runCommand "nix-archive" {
          buildInputs = [ nix pkgs.gnutar pkgs.gzip ];
          closureInfo = pkgs.closureInfo { rootPaths =  [ nix ]; };
          fileName = "nix-${nix.version}-${system}.tar.gz";
          inherit nix;
        } ''
          mkdir -p "$out" root/nix/var/nix
          NIX_STATE_DIR="$(pwd)/root/nix/var/nix" nix-store --load-db \
            < $closureInfo/registration
          ln -s $nix root/nix/.nix
          tar -czvT $closureInfo/store-paths -C root nix -f "$out/$fileName"
        '';

      nixVersions = system: lib.listToAttrs (map (nix: lib.nameValuePair
        nix.version nix
      ) (
        [ nixpkgs-nix-2_4.legacyPackages.${system}.nix
          nixpkgs-nix-2_3_15.legacyPackages.${system}.nix
          nixpkgs-nix-2_3_14.legacyPackages.${system}.nix
          nixpkgs-nix-2_3_12.legacyPackages.${system}.nix
          nixpkgs-nix-2_3_10.legacyPackages.${system}.nix
          nixpkgs-nix-2_3_7.legacyPackages.${system}.nix
          (import nixpkgs-nix-2_2_2 { inherit system; }).nix
          (import nixpkgs-nix-2_1_3 { inherit system; }).nix
        ] ++ lib.optionals (system == "x86_64-linux") [
          (import nixpkgs-nix-2_0_4 { inherit system; }).nix
        ]
      ));

      nixPackages = lib.mapAttrs'
        (v: p: lib.nameValuePair "nix-${lib.replaceStrings ["."] ["_"] v}" p)
        (nixVersions system);

      nixArchives = system: lib.mapAttrs (_: makeNixArchive) (nixVersions system);

      allNixArchives = lib.concatMap (system:
        map (version: {
          inherit system version;
          fileName = "nix-${version}-${system}.tar.zstd";
        }) (lib.attrNames (nixArchives system))
      ) allSystems;

    in rec {
      defaultApp = apps.release;

      apps.release= flake-utils.lib.mkApp { drv = packages.release; };

      packages = nixPackages // {
        nix-archives = preferRemoteBuild (pkgs.buildEnv {
          name = "nix-archives";
          paths = lib.attrValues (nixArchives system);
        });
        release = preferRemoteBuild (pkgs.writeScriptBin "release" ''
          #!${pkgs.stdenv.shell}

          PATH="${lib.makeBinPath (with pkgs; [
            coreutils gitMinimal github-cli
          ])}"

          if [ "$GITHUB_ACTIONS" != "true" ]; then
            echo >&2 "not running in GitHub, exiting"
            exit 1
          fi

          set -euo pipefail

          nix_archives="$1"
          release_file="$2"
          release="$(head -n1 "$release_file")"
          prev_release="$(gh release list -L 1 | cut -f 3)"

          if [ "$release" = "$prev_release" ]; then
            echo >&2 "Release tag not updated ($release)"
            exit
          else
            release_notes="$(mktemp)"
            tail -n+2 "$release_file" > "$release_notes"

            echo "" | cat >>"$release_notes" - "${pkgs.writeText "notes" ''
              ## Supported Nix Versions on Linux Runners
              ${lib.concatStringsSep "\n" (
                map (v: "* ${v}") (
                  lib.reverseList (lib.naturalSort (lib.attrNames (nixArchives "x86_64-linux")))
                )
              )}

              ## Supported Nix Versions on MacOS Runners
              ${lib.concatStringsSep "\n" (
                map (v: "* ${v}") (
                  lib.reverseList (lib.naturalSort (lib.attrNames (nixArchives "x86_64-darwin")))
                )
              )}
            ''}"

            echo >&2 "New release: $prev_release -> $release"
            gh release create "$release" ${
              lib.concatMapStringsSep " " ({ system, version, fileName }:
                ''"$nix_archives/${fileName}#nix-${version}-${system}"''
              ) allNixArchives
            } \
              --title "$GITHUB_REPOSITORY@$release" \
              --notes-file "$release_notes"
          fi
        '');
      };
    }
  );
}
