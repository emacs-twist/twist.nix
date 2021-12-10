inputs:
pkgs:
let
  lib = import ./build-support {
    inherit inputs;
    inherit (pkgs) lib;
  };
in
{
  emacsTwist = lib.makeOverridable (import ./emacs {
    inherit pkgs lib;
  });
}
