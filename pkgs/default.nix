inputs: final: prev: let
  lib = import ./build-support {
    inherit inputs;
    pkgs = prev;
  };
in {
  emacsTwist = lib.makeOverridable (import ./emacs {
    inherit final lib;
    pkgs = prev;
  });
}
