inputs:
let
  makeFromElisp = lib: (inputs.elisp-helpers.lib.makeLib { inherit lib; }).fromElisp;

  inherit (builtins)
    readFile
    split
    filter
    isString
    removeAttrs
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

  # A function that builds a single Emacs Lisp package. The argument should be
  # an attribute set that takes the same form as an entry value in
  # packageInputs. Most attributes for basic usage are self-explanatory, but it
  # requires elispInputs, which is a list of derivations that contain Emacs Lisp
  # source files in share/emacs/site-lisp directory and (optional)
  # native-compiled libraries in share/emacs/native-lisp directory.
  buildElispPackage =
    pkgs:
    pkgs.callPackage ../pkgs/emacs/build {
      lib = import ../pkgs/build-support {
        inherit inputs pkgs;
      };
    };

  # A non-overlay API that builds a configuration environment.
  makeEnv = { pkgs, ... }@args: import ../pkgs { inherit inputs pkgs; } (removeAttrs args [ "pkgs" ]);
}
