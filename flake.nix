{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # Latest commit on master
    nixpkgs.url = "github:nixos/nixpkgs/cb48717c767376d77c490b2d67f2a6a845deb714";
    # These are versions available in nixpkgs.
    # We assume they're still relevant 
    # and previous versions aren't.
    # 
    # We use Nix from the repo
    # because nixpkgs versions don't work 
    # in GitHub Actions.
    nix_2_28.url = "github:nixos/nix/2.28.5";
    nix_2_29.url = "github:nixos/nix/2.29.2";
    nix_2_30.url = "github:nixos/nix/2.30.3";
    nix_2_31.url = "github:nixos/nix/2.31.2";
    nix_2_32.url = "github:nixos/nix/2.32.4";
    nix_2_33.url = "github:nixos/nix/2.33.0";
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
    nix_2_28,
    nix_2_29,
    nix_2_30,
    nix_2_31,
    nix_2_32,
    nix_2_33,
  }:
  let allSystems = [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
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
          # TODO enable after the issue is fixed:
          # https://github.com/NixOS/nixpkgs/issues/467200
          # (self: super: super.prefer-remote-fetch self super)
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
          nix_2_28.packages.${system}.nix
          nix_2_29.packages.${system}.nix
          nix_2_30.packages.${system}.nix
          nix_2_31.packages.${system}.nix
          nix_2_32.packages.${system}.nix
          nix_2_33.packages.${system}.nix
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

            echo "" | cat >>"$release_notes" - "${pkgs.writeText "notes" (
              lib.concatMapStringsSep "\n" (sys: ''
                ## Supported Nix Versions on ${sys} runners
                ${lib.concatStringsSep "\n" (
                  map (v: "* ${v}") (
                    lib.reverseList (lib.naturalSort (lib.attrNames (nixArchives sys)))
                  )
                )}
              '') [
                 "x86_64-linux"
                 "aarch64-linux"
                 "x86_64-darwin"
                 "aarch64-darwin"
              ]
            )}"

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
