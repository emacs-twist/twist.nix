{ lib
, runCommandLocal
, makeWrapper
, linkFarm
, emacs
, lndir
, elispPackages
, executablePackages
}:
let
  inherit (builtins) length;

  # Use a symlink farm for specifying subdirectory names inside site-lisp.
  packagesAsFarm = linkFarm "emacs-dependencies-${emacs.version}"
    (map
      ({ ename, src, version, outPath, ... }:
        {
          # Construct a directory name prefixed with the ename.
          name = "${ename}-${lib.makeSourceVersion version src}";
          path = outPath;
        })
      elispPackages);
in
runCommandLocal "emacs"
{
  buildInputs = [ lndir ];
  propagatedBuildInputs = [ emacs packagesAsFarm ] ++ executablePackages;
  nativeBuildInputs = [ makeWrapper ];
}
  ''
    for dir in bin share/applications share/icons
    do
      mkdir -p $out/$dir
      lndir ${emacs}/$dir $out/$dir
    done

    siteLisp=$out/share/emacs/site-lisp
    mkdir -p $siteLisp/elpa
    for dep in ${packagesAsFarm}/*
    do
      ln -s $dep/share/emacs/site-lisp $siteLisp/elpa/$(basename $dep)
    done
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
