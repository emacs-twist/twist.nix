inputs:
pkgs:
let
  lib = import ./build-support {
    inherit inputs pkgs;
  };
in
{
  emacsTwist = lib.makeOverridable (import ./emacs {
    inherit pkgs lib;
  });
}
