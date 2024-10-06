# Helpers for testing
{
  pkgs ? import <nixpkgs> { },
}:
let
  elispHelpers = (builtins.getFlake "github:emacs-twist/elisp-helpers").lib.makeLib {
    inherit (pkgs) lib;
  };
in
{
  inherit (elispHelpers) fromElisp;
}
