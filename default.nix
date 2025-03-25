let
  pins = import ./npins;

  nixpkgs = import pins.nixpkgs { };
in

{
  pkgs ? nixpkgs,
}:

{
  inherit pkgs;
}
