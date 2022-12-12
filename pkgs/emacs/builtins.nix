{
  stdenv,
  emacs,
  ripgrep,
}: let
  inherit (emacs) version;
in
  stdenv.mkDerivation {
    name = "${emacs.name}-libraries";
    inherit (emacs) src;

    buildInputs = [ripgrep];

    phases = ["unpackPhase" "buildPhase"];

    buildPhase = ''
      cd lisp
      rg --maxdepth 2 --files-with-matches -g '*.el' \
        'This file is part of GNU Emacs.' \
        | grep -o -E '([^/]+)\.el' \
        | sed -e 's/\.el$//' \
        | sort \
        | uniq \
        > $out
    '';
  }
