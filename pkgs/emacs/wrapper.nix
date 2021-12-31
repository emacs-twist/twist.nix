{ lib
, runCommandLocal
, makeWrapper
, buildEnv
, emacs
, lndir
, texinfo
, elispInputs
, executablePackages
}:
let
  inherit (builtins) length;

  nativeComp = emacs.nativeComp or false;

  # Use a symlink farm for specifying subdirectory names inside site-lisp.
  packageEnv = buildEnv {
    name = "elisp-packages";
    paths = elispInputs;
    pathsToLink = [
      "/share/info"
      "/share/doc"
    ] ++ lib.optional nativeComp "/share/emacs/native-lisp";
    extraOutputsToInstall = [ "info" "doc" ];
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

  selfInfo = builtins.path {
    name = "emacs-twist.info";
    path = ../../doc/emacs-twist.info;
  };
in
runCommandLocal "emacs"
{
  buildInputs = [ lndir texinfo ];
  propagatedBuildInputs = [ emacs packageEnv ] ++ executablePackages;
  nativeBuildInputs = [ makeWrapper ];
  # Useful for use with flake-utils.lib.mkApp
  passthru.exePath = "/bin/emacs";

  passAsFile = [ "subdirs" ];

  nativeLoadPath =
    "${packageEnv}/share/emacs/native-lisp/:${emacs}/share/emacs/native-lisp/:";
  subdirs = lib.concatMapStrings
    (path: "(push \"${path}/share/emacs/site-lisp/\" load-path)\n") elispInputs;
}
  ''
    for dir in bin share/applications share/icons
    do
      mkdir -p $out/$dir
      lndir -silent ${emacs}/$dir $out/$dir
    done

    siteLisp=$out/share/emacs/site-lisp
    mkdir -p $siteLisp
    if [[ -e $subdirsPath ]]
    then
      install -m 444 $subdirsPath $siteLisp/subdirs.el
    else
      echo -n "$subdirs" > $siteLisp/subdirs.el
    fi

    mkdir -p $out/share/doc
    lndir -silent ${packageEnv}/share/doc $out/share/doc

    mkdir -p $out/share/info
    install ${selfInfo} $out/share/info/emacs-twist.info
    install-info $out/share/info/emacs-twist.info $out/share/info/dir

    for bin in $out/bin/*
    do
      if [[ $(basename $bin) = emacs-* ]]
      then
      wrapProgram $bin \
        ${lib.optionalString (length executablePackages > 0) (
          "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath executablePackages)}"
        )} \
        --prefix INFOPATH : ${emacs}/share/info:$out/share/info:${packageEnv}/share/info \
        ${lib.optionalString nativeComp "--set EMACSNATIVELOADPATH $nativeLoadPath"
        } \
        --set EMACSLOADPATH "$siteLisp:"
      fi
    done
  ''
