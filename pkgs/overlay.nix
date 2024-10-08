# This is a deprecated API which adds `emacsTwist` function to nixpkgs.
# It is recommended to use the function provided under lib.
inputs: final: prev:
let
  lib = import ./build-support {
    inherit inputs;
    pkgs = prev;
  };
in
{
  emacsTwist =
    args:
    lib.warn "The overlay API of twist is now deprecated." (
      lib.makeOverridable (import ./emacs {
        inherit final lib;
        pkgs = prev;
      }) args
    );
}
