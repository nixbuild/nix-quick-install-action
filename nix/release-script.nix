{
  lib,
  writeShellApplication,
  writeText,

  coreutils,
  gitMinimal,
  github-cli,

  lixArchives,
  nixArchives,
  allArchives,
}:

let
  makeSupportedVersions =
    name: archives:
    lib.concatMapStringsSep "\n"
      (
        system:
        let
          inherit (lib) attrNames naturalSort reverseList;

          mkMarkdownList = map (s: "- ${s}");
          sortedVersions = reverseList (naturalSort (attrNames (archives system)));
        in
        ''
          ## Supported ${name} versions on ${system}:
          ${lib.concatStringsSep "\n" (mkMarkdownList sortedVersions)}
        ''
      )
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

  supportedVersions = writeText "supportedVersions" ''
    ${makeSupportedVersions "Lix" lixArchives}
    ${makeSupportedVersions "Nix" nixArchives}
  '';

  releaseAssets = lib.concatMapStringsSep " " (
    {
      system,
      version,
      impl,
      fileName,
    }:
    "\"$nix_archives/${fileName}#${impl}-${version}-${system}\""
  ) allArchives;
in

writeShellApplication {
  name = "release";

  runtimeInputs = [
    coreutils
    gitMinimal
    github-cli
  ];

  text = ''
    if [ "$GITHUB_ACTIONS" != "true" ]; then
      echo >&2 "not running in GitHub, exiting"
      exit 1
    fi

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

      echo "" | cat >>"$release_notes" - "${supportedVersions}"

      echo >&2 "New release: $prev_release -> $release"

      gh release create "$release" ${releaseAssets} \
          --title "$GITHUB_REPOSITORY@$release" \
          --notes-file "$release_notes"
    fi
  '';
}
