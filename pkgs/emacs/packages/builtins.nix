{ lib, stdenv, ripgrep }: emacs:
assert emacs ? src;
let
  inherit (emacs) version;

  path = stdenv.mkDerivation {
    name = "${emacs.name}-libraries";
    inherit (emacs) src;

    preferLocalBuild = true;
    allowSubstitutes = false;

    buildInputs = [ ripgrep ];

    phases = [ "unpackPhase" "buildPhase" ];

    buildPhase = ''
      echo "Comparing Emacs versions..."
      decl=$(grep -oP "This directory tree holds version \d[.\d]+\d of GNU Emacs" README)
      if [[ "$decl" =~ [1-9][.0-9]+[0-9] ]]
      then
        version=''${BASH_REMATCH[0]}
        echo "  Expected: ${version}"
        echo "  Actual:   $version"
        if [[ $version != ${version} ]]
        then
          "ERROR: The version mismatched. Please fix the version."
          exit 1
        fi
      else
        echo "Did not find a version from the README." >&2
        exit 1
      fi

      cd lisp
      rg --maxdepth 2 --files-with-matches -g '*.el' \
        'This file is part of GNU Emacs.' \
        | grep -o -E '([^/]+)\.el' \
        | sed -e 's/\.el$//' \
        | sort \
        | uniq \
        > $out
    '';
  };

  inherit (builtins) readFile split filter isString;
in
lib.pipe (readFile path) [
  (split "\n")
  (filter (s: isString s && s != ""))
]
