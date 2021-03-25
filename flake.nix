{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable-small";
    nixpkgs-nix-unstable-20201205.url = "nixpkgs/8377eef0274f7945be3b195ebb99398309a55826";
    nixpkgs-nix-unstable-20200829.url = "nixpkgs/eb6e2ac2c033a86afa6a606753aab0dbde8bddda";
    nixpkgs-nix-2_3_10.url = "nixpkgs/31999436daf18dc4f98559304aa846613dd821bb";
    nixpkgs-nix-2_3_7.url = "nixpkgs/046427570ebe2726a2f21c3b51d84d29c86ebde5";
    nixpkgs-nix-2_2_2.url = "nixpkgs/5399f34ad9481849720d14605ce87b81abe202e9";
    nixpkgs-nix-2_2_2.flake = false;
    nixpkgs-nix-2_1_3.url = "nixpkgs/2c9265c95075170ad210ed5635ecffcd36db6b84";
    nixpkgs-nix-2_1_3.flake = false;
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nixpkgs-nix-unstable-20201205,
    nixpkgs-nix-unstable-20200829,
    nixpkgs-nix-2_3_10,
    nixpkgs-nix-2_3_7,
    nixpkgs-nix-2_2_2,
    nixpkgs-nix-2_1_3
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
          buildInputs = [ nix pkgs.gnutar pkgs.zstd ];
          closureInfo = pkgs.closureInfo { rootPaths =  [ nix ]; };
          fileName = "nix-${nix.version}-${system}.tar.zstd";
          inherit nix;
        } ''
          mkdir -p "$out" root/nix/var/nix
          NIX_STATE_DIR="$(pwd)/root/nix/var/nix" nix-store --load-db \
            < $closureInfo/registration
          ln -s $nix root/nix/.nix
          tar -cvT $closureInfo/store-paths -C root nix | zstd - -o "$out/$fileName"
        '';

      nixArchives = lib.listToAttrs (map (nix: lib.nameValuePair
        nix.version (makeNixArchive nix)
      ) [
        pkgs.nixUnstable
        nixpkgs-nix-unstable-20201205.legacyPackages.${system}.nixUnstable
        nixpkgs-nix-unstable-20200829.legacyPackages.${system}.nixUnstable
        nixpkgs-nix-2_3_10.legacyPackages.${system}.nix
        nixpkgs-nix-2_3_7.legacyPackages.${system}.nix
        (import nixpkgs-nix-2_2_2 { inherit system; }).nix
        (import nixpkgs-nix-2_1_3 { inherit system; }).nix
      ]);

      allNixArchives = lib.crossLists (system: version: rec {
        inherit system version;
        fileName = "nix-${version}-${system}.tar.zstd";
      }) [ allSystems (lib.attrNames nixArchives) ];

    in rec {
      defaultApp = apps.release;

      apps.release= flake-utils.lib.mkApp { drv = packages.release; };

      packages = {
        nix-archives = preferRemoteBuild (pkgs.buildEnv {
          name = "nix-archives";
          paths = lib.attrValues nixArchives;
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
              ## Supported Nix Versions
              ${lib.concatStringsSep "\n" (
                map (v: "* ${v}") (lib.reverseList (lib.attrNames nixArchives))
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
