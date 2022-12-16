{
  stdenv,
  emacs,
  ripgrep,
}: stdenv.mkDerivation {
    pname = "emacs-builtins-list";
    inherit (emacs) src version;

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
