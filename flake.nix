{
  description = "nix-quick-install-action";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/632f04521e847173c54fa72973ec6c39a371211c";

    lix-2_92 = {
      url = "https://git.lix.systems/lix-project/lix/archive/2.92.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
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

    lix-2_92,
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

      makeNixArchive = name: nix:
        pkgs.runCommand "${name}-archive" {
          buildInputs = [ nix pkgs.gnutar pkgs.zstd ];
          closureInfo = pkgs.closureInfo { rootPaths =  [ nix ]; };
          fileName = "${name}-${nix.version}-${system}.tar.zstd";
          inherit nix;
        } ''
          mkdir -p "$out" root/nix/var/{nix,nix-quick-install-action}
          ln -s $nix root/nix/var/nix-quick-install-action/nix
          cp -t root/nix/var/nix-quick-install-action $closureInfo/registration
          tar -cvT $closureInfo/store-paths -C root nix | zstd -o "$out/$fileName"
        '';

      mkVersions = packages: system: lib.listToAttrs (map (nix: lib.nameValuePair
        nix.version nix
      ) (packages system));

      mkPackages = name: versions: lib.mapAttrs'
        (v: p: lib.nameValuePair "${name}-${lib.replaceStrings ["."] ["_"] v}" p)
        (versions system);

      mkArchives = name: versions: system: lib.mapAttrs (_: makeNixArchive name) (versions system);

      nixVersions = mkVersions (system:
        [
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_26
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_25
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.nix_2_24
        ] ++
        lib.optionals (system != "aarch64-linux")
        [
          nixpkgs-unstable.legacyPackages.${system}.nixVersions.minimum
        ]
      );
      lixVersions = mkVersions (system:
        [
          lix-2_92.packages.${system}.nix
          nixpkgs-unstable.legacyPackages.${system}.lixVersions.lix_2_91
          nixpkgs-unstable.legacyPackages.${system}.lixVersions.lix_2_90
        ]
      );

      nixPackages = mkPackages "nix" nixVersions;
      lixPackages = mkPackages "lix" lixVersions;

      nixArchives = mkArchives "nix" nixVersions;
      lixArchives = mkArchives "lix" lixVersions;

      mkAllArchives = name: archives: lib.concatMap (system:
        map (version: {
          inherit system version;
          impl = name;
          fileName = "${name}-${version}-${system}.tar.zstd";
        }) (lib.attrNames (archives system))
      ) allSystems;

      allArchives = (mkAllArchives "nix" nixArchives) ++ (mkAllArchives "lix" lixArchives);
    in rec {
      defaultApp = apps.release;

      apps.release = flake-utils.lib.mkApp { drv = packages.release; };

      overlays = final: prev: nixPackages;

      packages = nixPackages // lixPackages // {
        nix-archives = preferRemoteBuild (pkgs.buildEnv {
          name = "nix-archives";
          paths = lib.attrValues ((nixArchives system) // (lixArchives system));
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

            echo "" | cat >>"$release_notes" - "${let
              mkSupported = name: archives: lib.concatMapStringsSep "\n" (sys: ''
                ## Supported ${name} Versions on ${sys} runners
                ${lib.concatStringsSep "\n" (
                  map (v: "* ${v}") (
                    lib.reverseList (lib.naturalSort (lib.attrNames (archives sys)))
                  )
                )}
              '') [
                 "x86_64-linux"
                 "aarch64-linux"
                 "x86_64-darwin"
                 "aarch64-darwin"
              ];
            in pkgs.writeText "notes" ''
              ${mkSupported "Lix" lixArchives}
              ${mkSupported "Nix" nixArchives}
            ''}"

            echo >&2 "New release: $prev_release -> $release"
            gh release create "$release" ${
              lib.concatMapStringsSep " " ({ system, version, impl, fileName }:
                ''"$nix_archives/${fileName}#${impl}-${version}-${system}"''
              ) allArchives
            } \
              --title "$GITHUB_REPOSITORY@$release" \
              --notes-file "$release_notes"
          fi
        '');
      };
    }
  );
}
