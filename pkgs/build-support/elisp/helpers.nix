/* Helpers for testing */
{pkgs ? import <nixpkgs> {}}: let
  inherit (builtins) fetchTree fromJSON readFile;
  elispHelpers = import (fetchTree (fromJSON (readFile ./flake.lock)).nodes.elisp-helpers.locked) {
    inherit pkgs;
  };
in {
  inherit (elispHelpers) fromElisp;
}
