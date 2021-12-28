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

  buildCmd = ''
    ls
    emacs --batch -L . --eval "(setq debug-on-error ${if debugOnError then "t" else "nil"})" \
      -f batch-byte-compile ${lib.escapeShellArgs (map stringBaseName lispFiles)}

    rm -f "${ename}-autoloads.el"
    emacs --batch -l package --eval "(package-generate-autoloads '${ename} \".\")"

    if [[ ! -e "${ename}-pkg.el" ]]
    then
      cat > ${ename}-pkg.el <<PKG
      (define-package "${ename}" "${version}"
        ""
        '(${
          # It may be necessary to include the version actually specified in the
          # header, but it won't matter anyway.
          lib.concatMapStrings (name: "(" + name + " \"0\")")
            (lib.catAttrs "ename" elispInputs)
        }))
      ;; Local Variables:
      ;; no-byte-compile: t
      ;; End:
    PKG
    fi
  '';

  hasFile = pred: (lib.findFirst pred null files != null);

  hasInfoOutput =
    # (elem "info" (meta.outputsToInstall or []))
    # &&
    hasFile (f: match ".+\\.(info|texi(nfo)?)" f != null);

  hasDocOutput =
    # Ignore Org files starting with an upper-case character
    # such as README.org, CHANGELOG.org, etc.
    hasFile (f: match "[a-z0-9].+\.(org|texi(nfo)?)" f != null);

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

  installInfo = ''
    mkdir -p $info/share
    install -d $info/share/info
    for i in *.info
    do
      install -t $info/share/info $i
    done
  '';

  installDoc = ''
    mkdir -p $doc/share
    install -d $doc/share/doc
    for d in *.texi *.texinfo *.org
    do
      if [[ ! $d =~ ^[A-Z] ]]
      then
        install -t $doc/share/doc $d
      fi
    done
  '';
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
      ++ lib.optional hasDocOutput "doc"
      ++ lib.optional hasInfoOutput "info";

  buildInputs = [ emacs texinfo ];
  # nativeBuildInputs = lib.optional nativeComp gcc;

  EMACSLOADPATH = lib.concatStrings
    (map (pkg: "${pkg.outPath}/share/emacs/site-lisp/elpa/${pkg.ename}-${pkg.version}:")
      elispInputs);

  buildPhase = ''
    export EMACSLOADPATH

    runHook preBuild

    ${buildCmd}

    ${lib.optionalString hasInfoOutput buildInfo}

    runHook postBuild
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

    lispDir=$out/share/emacs/site-lisp/elpa/$ename-$version
    install -d $lispDir
    tar cf - --exclude='*.info' --exclude='eln-cache' . \
      | (cd $lispDir && tar xf -)

    ${lib.optionalString (nativeComp && nativeCompileAhead) buildAndInstallNativeLisp}

    ${lib.optionalString hasDocOutput installDoc}

    ${lib.optionalString hasInfoOutput installInfo}

    runHook postInstall
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
