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

  buildElpaArchive =
    pkgs: attrs:
    let
      lib = import ../pkgs/build-support {
        inherit inputs pkgs;
      };
      attrs' = {
        elispInputs = [ ];
        dontByteCompile = true;
        wantExtraOutputs = true;
        nativeCompileAhead = false;
      } // attrs;

      convertToElpaArchive = pkgs.callPackage ../pkgs/build-support/elisp/convertToElpaArchive.nix { };
    in
    convertToElpaArchive attrs (pkgs.callPackage ../pkgs/emacs/build { inherit lib; } attrs');
}
