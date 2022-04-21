inputs: final: pkgs: let
  lib = import ./build-support {
    inherit inputs pkgs;
  };
in {
  emacsTwist = lib.makeOverridable (import ./emacs {
    inherit final pkgs lib;
  });
}
