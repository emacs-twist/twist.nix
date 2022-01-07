inputs:
{ lib
}:
let
  fromElisp = import inputs.fromElisp {
    pkgs = { inherit lib; };
  };
in
{
  parseSetup = import ../pkgs/build-support/elisp/parseSetup.nix {
    inherit lib fromElisp;
  };

  parseUsePackages = import ../pkgs/build-support/elisp/parseUsePackages.nix {
    inherit lib fromElisp;
  };
}
