{ lib, stdenv, emacs, texinfo }:
{ ename
, src
, version
, files
, lispFiles
, meta
, nativeCompileAhead
, elispInputs
# Whether to fail on byte-compile warnings
, debugOnError ? false
, ...
} @ attrs:
with builtins;
let
  nativeComp = emacs.nativeComp or false;

  regex = ".*/([^/]+)";

  stringBaseName = file:
    if match regex file != null
    then head (match regex file)
    else file;

  hasFile = pred: (lib.findFirst pred null files != null);

  canProduceInfo = hasFile (f: match ".+\\.(info|texi(nfo)?)" f != null);
in
stdenv.mkDerivation (rec {
  inherit src ename meta version;

  pname = concatStringsSep "-" [
    (replaceStrings [ "." ] [ "-" ] emacs.name)
    (lib.toPName ename)
  ];

  preferLocalBuild = true;
  allowSubstitutes = false;

  outputs =
    [ "out" ]
    ++ lib.optional canProduceInfo "info";

  buildInputs = [ emacs texinfo ];
  # nativeBuildInputs = lib.optional nativeComp gcc;

  EMACSLOADPATH = lib.concatStrings
    (map (pkg: "${pkg.outPath}/share/emacs/site-lisp/:")
      elispInputs);

  buildPhase = ''
    export EMACSLOADPATH

    runHook preBuild

    runHook buildCmd

    if [[ " ''${outputs[*]} " = *" info "* ]]
    then
      runHook buildInfo
    fi

    runHook postBuild
  '';

  buildCmd = ''
    ls
    emacs --batch -L . --eval "(setq debug-on-error ${if debugOnError then "t" else "nil"})" \
      -f batch-byte-compile ${lib.escapeShellArgs (map stringBaseName lispFiles)}

    rm -f "${ename}-autoloads.el"
    emacs --batch -l autoload \
        --eval "(setq generated-autoload-file \"${ename}-autoloads.el\")" \
        -f batch-update-autoloads .
  '';

  buildInfo = ''
    cwd="$PWD"
    cd $src
    for d in $(find -name '*.texi' -o -name '*.texinfo')
    do
      local basename=$(basename $d)
      local i=$cwd/''${basename%%.*}.info
      if [[ ! -e "$i" ]]
      then
        cd $src/$(dirname $d)
        makeinfo --no-split "$basename" -o "$i"
      fi
    done
    cd $cwd
  '';

  EMACSNATIVELOADPATH = "${
    lib.makeSearchPath "share/emacs/native-lisp/" elispInputs
  }:";

  # Because eln depends on the file name hash of the source file, native
  # compilation must be done after the elisp files are installed. For details,
  # see the documentation of comp-el-to-eln-rel-filename.
  buildAndInstallNativeLisp = ''
    nativeLispDir=$out/share/emacs/native-lisp
    mkdir -p $nativeLispDir

    EMACSLOADPATH="$EMACSLOADPATH" EMACSNATIVELOADPATH="$EMACSNATIVELOADPATH" \
      emacs --batch -L $lispDir -l ${./comp-native.el} \
        --eval "(push \"$nativeLispDir/\" native-comp-eln-load-path)" \
        --eval "(setq native-compile-target-directory \"$nativeLispDir/\")" \
        -f run-native-compile-sync $lispDir
  '';

  installPhase = ''
    runHook preInstall

    lispDir=$out/share/emacs/site-lisp/
    install -d $lispDir
    tar cf - \
      --exclude='*.info' \
      --exclude='*.texi' \
      --exclude='*.texinfo' \
      --exclude='eln-cache' \
      . \
      | (cd $lispDir && tar xf -)

    ${lib.optionalString (nativeComp && nativeCompileAhead) buildAndInstallNativeLisp}

    if [[ " ''${outputs[*]} " = *" info "* ]]
    then
      runHook installInfo
    fi

    runHook postInstall
  '';

  installInfo = ''
    mkdir -p $info/share
    install -d $info/share/info
    # Exclude files that can conflict across multiple packages.
    rm -f gpl.info contributors.info fdl.info
    for i in *.info
    do
      install -t $info/share/info $i
    done
  '';

} // lib.optionalAttrs attrs.customUnpackPhase {
  # TODO: Handle :rename of ELPA packages
  # See https://git.savannah.gnu.org/cgit/emacs/elpa.git/plain/README for details.
  unpackPhase = ''
    for file in ${lib.escapeShellArgs files}
    do
      cp -r $src/$file .
    done
  '';
})
