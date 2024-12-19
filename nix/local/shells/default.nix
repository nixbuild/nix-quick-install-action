{ inputs, cell }:
let
  inherit (inputs.std) lib std;
  inherit (cell) settings;
in
{
  default = lib.dev.mkShell {
    name = "lix-quick-install-action";

    imports = [ std.devshellProfiles.default ];

    nixago = [
      settings.editorconfig
      settings.treefmt
    ];
  };
}
