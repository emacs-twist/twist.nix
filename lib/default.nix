inputs: {lib}: let
  elispHelpers = import inputs.elisp-helpers {
    pkgs = {inherit lib;};
  };

  inherit (elispHelpers) fromElisp;

  inherit (builtins) readFile split filter isString;
in {
  parseSetup = import ../pkgs/build-support/elisp/parseSetup.nix {
    inherit lib fromElisp;
  };

  parseUsePackages = import ../pkgs/build-support/elisp/parseUsePackages.nix {
    inherit lib fromElisp;
  };

  emacsBuiltinLibraries = {
    stdenv,
    ripgrep,
    emacs,
  } @ args:
    lib.pipe (readFile (import ../pkgs/emacs/builtins.nix args)) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];
}
