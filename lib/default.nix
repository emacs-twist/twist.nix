inputs:
{ lib
}:
let
  fromElisp = import inputs.fromElisp {
    pkgs = { inherit lib; };
  };

  parseSetup' = import ../pkgs/build-support/elisp/parseSetup.nix {
    inherit lib fromElisp;
  };
in
{
  parseSetup = parseSetup' { };
  # Like parseSetup, but allows customization.
  inherit parseSetup';

  parseUsePackages = import ../pkgs/build-support/elisp/parseUsePackages.nix {
    inherit lib fromElisp;
  };
}
