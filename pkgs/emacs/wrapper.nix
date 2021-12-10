{ lib
, runCommandLocal
, makeWrapper
, buildEnv
, emacs
, lndir
, elispPackages
, executablePackages
}:
let
  inherit (builtins) length;

  # Use a symlink farm for specifying subdirectory names inside site-lisp.
  packageEnv = buildEnv {
    name = "elisp-packages";
    paths = elispPackages;
    pathsToLink = [
      "/share/emacs/site-lisp/elpa"
    ];
  };
in
runCommandLocal "emacs"
{
  buildInputs = [ lndir ];
  propagatedBuildInputs = [ emacs packageEnv ] ++ executablePackages;
  nativeBuildInputs = [ makeWrapper ];
}
  ''
    for dir in bin share/applications share/icons
    do
      mkdir -p $out/$dir
      lndir ${emacs}/$dir $out/$dir
    done

    siteLisp=$out/share/emacs/site-lisp
    mkdir -p $siteLisp
    ln -t $siteLisp -s ${packageEnv}/share/emacs/site-lisp/elpa
    ln -t $siteLisp -s ${emacs}/share/emacs/site-lisp/subdirs.el

    for bin in $out/bin/*
    do
      if [[ $(basename $bin) = emacs-* ]]
      then
      wrapProgram $bin \
        ${lib.optionalString (length executablePackages > 0) (
          "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath executablePackages)}"
        )} \
        --set EMACSLOADPATH "$siteLisp:"
      fi
    done
  ''
