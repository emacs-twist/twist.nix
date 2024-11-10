{ inputs, pkgs }:
let
  lib = import ./build-support {
    inherit pkgs inputs;
  };
in
lib.makeOverridable (
  import ./emacs {
    inherit lib pkgs;
  }
)
