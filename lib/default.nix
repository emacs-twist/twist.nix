inputs:
let
  makeFromElisp =
    lib:
    (import inputs.elisp-helpers {
      pkgs = {
        inherit lib;
      };
    }).fromElisp;

  inherit (builtins)
    readFile
    split
    filter
    isString
    ;
in
{
  parseSetup =
    { lib }:
    import ../pkgs/build-support/elisp/parseSetup.nix {
      inherit lib;
      fromElisp = makeFromElisp lib;
    };

  parseUsePackages =
    { lib }:
    import ../pkgs/build-support/elisp/parseUsePackages.nix {
      inherit lib;
      fromElisp = makeFromElisp lib;
    };

  emacsBuiltinLibraries =
    {
      stdenv,
      ripgrep,
      emacs,
      lib,
    }@args:
    lib.pipe (readFile (import ../pkgs/emacs/builtins.nix args)) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];
}
