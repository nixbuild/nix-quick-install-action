# deadnix: skip
{ inputs, cell }:
let
  l = pkgs.lib // builtins;

  inherit (cell) pkgs;

  mkLixTarball =
    lix:
    pkgs.runCommand "mk-lix-tarball"
      {
        buildInputs = [
          lix
          pkgs.gnutar
          pkgs.zstd
        ];
        closureInfo = pkgs.closureInfo { rootPaths = [ lix ]; };
        fileName = "lix-${lix.version}-${lix.system}.tar.zstd";
        inherit lix;
      }
      ''
        mkdir -p root/nix/var/{nix,lix-quick-install-action} "$out"
        ln -s "$lix" root/nix/var/lix-quick-install-action/lix
        cp {"$closureInfo",root/nix/var/lix-quick-install-action}/registration
        tar --auto-compress --create --directory=root --file="$out/$fileName" --files-from="$closureInfo"/store-paths nix
      '';
in
{
  lix-tarballs =
    (pkgs.buildEnv {
      name = "lix-tarballs";
      paths = l.pipe pkgs.lixVersions [
        (l.filterAttrs (_: l.isDerivation))
        (l.mapAttrs' (_: drv: l.nameValuePair drv.version drv))
        (l.mapAttrsToList (_: mkLixTarball))
      ];
    }).overrideAttrs
      {
        preferLocalBuild = false;
        allowSubstitutes = true;
      };
}
