{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-unstable.url = "nixpkgs/f22fdce31b752f2fe308cbf784bb211b4d650a9a";
    nixpkgs-nix-2_9_2.url = "nixpkgs/593d839e8fadea1183e071186ae1b584792d4884";
    nixpkgs-nix-2_5_1.url = "nixpkgs/89f196fe781c53cb50fef61d3063fa5e8d61b6e5";
    nixpkgs-nix-2_4.url = "nixpkgs/e912008eef096f52f28cf87492830c54ef334eb4";
    nixpkgs-nix-2_2_2.url = "nixpkgs/5399f34ad9481849720d14605ce87b81abe202e9";
    nixpkgs-nix-2_2_2.flake = false;
    nixpkgs-nix-2_1_3.url = "nixpkgs/2c9265c95075170ad210ed5635ecffcd36db6b84";
    nixpkgs-nix-2_1_3.flake = false;
    nixpkgs-nix-2_0_4.url = "nixpkgs/47b85dc5ab8243a653c20d4851a3e6c966877251";
    nixpkgs-nix-2_0_4.flake = false;
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
    nixpkgs-nix-2_9_2,
    nixpkgs-nix-2_5_1,
    nixpkgs-nix-2_4,
    nixpkgs-nix-2_2_2,
    nixpkgs-nix-2_1_3,
    nixpkgs-nix-2_0_4
  }:
  let allSystems = ["x86_64-linux" "x86_64-darwin"];
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
        [ nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_16
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_15
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_14
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_13
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_12
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_11
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_10
          nixpkgs-nix-2_9_2.legacyPackages.${system}.nixVersions.nix_2_9
          nixpkgs-nix-2_9_2.legacyPackages.${system}.nixVersions.nix_2_8
          nixpkgs-nix-2_9_2.legacyPackages.${system}.nixVersions.nix_2_7
          nixpkgs-nix-2_9_2.legacyPackages.${system}.nixVersions.nix_2_6
          nixpkgs-nix-2_5_1.legacyPackages.${system}.nix
          nixpkgs-nix-2_4.legacyPackages.${system}.nix
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.minimum
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
