let
  inherit (import ./default.nix { }) pkgs;
in

pkgs.mkShell {
  name = "lix-quick-install-action-devshell";
  packages = with pkgs; [
    nixfmt-rfc-style
    nixd
    npins
  ];
}
