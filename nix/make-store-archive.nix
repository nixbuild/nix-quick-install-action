{
  runCommand,
  closureInfo,

  gnutar,
  zstd,
}:

system: name: lix:

runCommand "${name}-archive"
  {
    buildInputs = [
      lix
      gnutar
      zstd
    ];

    closureInfo = closureInfo { rootPaths = [ lix ]; };
    fileName = "${name}-${lix.version}-${system}.tar.zstd";
  }
  ''
    mkdir -p $out root/nix/var/{nix,lix-quick-install-action}
    ln -s ${lix} root/nix/var/lix-quick-install-action/lix
    cp $closureInfo/registration root/nix/var/lix-quick-install-action
    tar -cvT $closureInfo/store-paths -C root nix | zstd -o "$out/$fileName"
  ''
