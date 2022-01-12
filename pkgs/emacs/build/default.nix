{ lib, stdenv, emacs, texinfo, gnumake }:
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
stdenv.mkDerivation ({
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

  buildInputs = [ emacs texinfo gnumake ];
  # nativeBuildInputs = lib.optional nativeComp gcc;

  # If the repository contains a Makefile, configurePhase can be problematic, so
  # exclude it.
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];

  renamePhase = lib.optionalString (attrs ? renames && attrs.renames != null) (
    lib.pipe attrs.renames [
      (lib.mapAttrsToList (origin: dest:
        "mv ${
          if lib.hasSuffix "/" origin
          then origin + "*.*"
          else lib.removeSuffix "/" origin
        } ${
          if dest == ""
          then "."
          else dest
        }"
      ))
      (concatStringsSep "\n")
    ]
  );

  EMACSLOADPATH = lib.concatStrings
    (map (pkg: "${pkg.outPath}/share/emacs/site-lisp/:")
      elispInputs);

  EMACSNATIVELOADPATH = "${
    lib.makeSearchPath "share/emacs/native-lisp/" elispInputs
  }:";

  buildCmd = ''
    emacs --batch -L . --eval "(setq debug-on-error ${if debugOnError then "t" else "nil"})" \
      -f batch-byte-compile ${lib.escapeShellArgs (map stringBaseName lispFiles)}

    rm -f "${ename}-autoloads.el"
    emacs --batch -l autoload \
        --eval "(setq generated-autoload-file \"${ename}-autoloads.el\")" \
        -f batch-update-autoloads .
  '';

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

  doNativeComp = nativeComp && nativeCompileAhead;

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

    if [[ -n "$doNativeComp" ]]
    then
      runHook buildAndInstallNativeLisp
    fi

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

}
//
{
  inherit (attrs) customUnpackPhase;

  preBuild = attrs.preBuild or "";

  buildPhase = ''
    export EMACSLOADPATH
    runHook preBuild

    if [[ -n "$customUnpackPhase" ]]
    then
      mkdir _build
      for file in ${lib.escapeShellArgs files}
      do
        cp -r $file _build
      done
      cd _build

      runHook renamePhase
    fi

    runHook buildCmd
    runHook postBuild

    if [[ " ''${outputs[*]} " = *" info "* ]]
    then
      runHook buildInfo
    fi
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
}
)
