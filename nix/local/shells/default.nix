{ inputs, cell }:
let
  inherit (inputs.std) lib std;
  inherit (cell) settings;
in
{
  default = lib.dev.mkShell {
    name = "action-lix-quick-install";

    imports = [ std.devshellProfiles.default ];

    nixago = [
      settings.editorconfig
      settings.treefmt
    ];
  };
}
