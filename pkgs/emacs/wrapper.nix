{ lib
, runCommandLocal
, makeWrapper
, buildEnv
, emacs
, lndir
, texinfo
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
      "/share/info"
    ];
    extraOutputsToInstall = [ "info" ];
    buildInputs = [
      texinfo
    ];
    postBuild = ''
      if [[ -w $out/share/info ]]
      then
        shopt -s nullglob
        for i in $out/share/info/*.info $out/share/info/*.info.gz; do
          install-info $i $out/share/info/dir
        done
      fi
    '';
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
      lndir -silent ${emacs}/$dir $out/$dir
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
        --prefix INFOPATH : ${emacs}/share/info:${packageEnv}/share/info \
        --set EMACSLOADPATH "$siteLisp:"
      fi
    done
  ''
