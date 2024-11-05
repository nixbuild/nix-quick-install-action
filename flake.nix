{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-unstable.url = "nixpkgs/ccc0c2126893dd20963580b6478d1a10a4512185";
  };

  nixConfig = {
    # We set some dummy Nix config here so we can use it for verification in our
    # CI test
    stalled-download-timeout = 333; # default 300
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs-unstable,
  }:
  let allSystems = [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
  in flake-utils.lib.eachSystem allSystems (system:

    let

      inherit (nixpkgs-unstable) lib;

      preferRemoteBuild = drv: drv.overrideAttrs (_: {
        preferLocalBuild = false;
        allowSubstitutes = true;
      });

      pkgs = import nixpkgs-unstable {
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
          mkdir -p "$out" root/nix/var/{nix,nix-quick-install-action}
          ln -s $nix root/nix/var/nix-quick-install-action/nix
          cp -t root/nix/var/nix-quick-install-action $closureInfo/registration
          tar -cvT $closureInfo/store-paths -C root nix | zstd -o "$out/$fileName"
        '';

      nixVersions = system: lib.listToAttrs (map (nix: lib.nameValuePair
        nix.version nix
      ) (
        [
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.latest
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_23
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_22
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_21
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_20
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_19
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_18
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.minimum
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

      apps.release = flake-utils.lib.mkApp { drv = packages.release; };

      overlays = final: prev: nixPackages;

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
