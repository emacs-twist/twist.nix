{ lib, stdenv, emacs, texinfo, elispPackages }:
{ ename
, src
, version
, files
, requiredPackages
, meta
, allowSkipCompiling ? false
, ...
} @ elispAttrs:
let
  inherit (builtins) concatStringsSep replaceStrings match elem;

  elispBuildInputs = lib.attrVals requiredPackages elispPackages;

  buildCmd = ''
    if ! emacs --batch -L . -f batch-byte-compile *.el
    then
      if [[ "${lib.boolToString allowSkipCompiling}" = true ]]
      then
        echo "warn: Byte-compile is skipped."
      else
        echo "To allow this error, set allowErrors.byteCompile to true."
        exit 1
      fi
    fi
    emacs --batch -l package --eval "(package-generate-autoloads '${ename} \".\")"

    if [[ ! -e "${ename}-pkg.el" ]]
    then
      cat > ${ename}-pkg.el <<PKG
      (define-package "${ename}" "${version}"
        "${meta.description or ""}"
        '())
      ;; Local Variables:
      ;; no-byte-compile: t
      ;; End:
    PKG
    fi
  '';

  emacsLoadPath = lib.concatStrings
    (map (pkg: "${pkg.outPath}/share/emacs/site-lisp/elpa/${pkg.ename}-${pkg.version}:")
        elispBuildInputs);

  hasInfoOutput =
    # (elem "info" (meta.outputsToInstall or []))
    # &&
    (lib.findFirst (f: match ".+\\.(info|texi(nfo)?)" f != null) null files
    != null);

  buildInfo = ''
    cwd="$PWD"
    cd $src
    for doc in $(find -name '*.texi' -o -name '*.texinfo')
    do
      local basename=$(basename $doc)
      cd $src/$(dirname $doc)
      makeinfo --no-split "$basename" -o $cwd/''${basename%%.*}.info
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

in
stdenv.mkDerivation rec {
  inherit src ename meta version;

  pname = concatStringsSep "-" [
    (replaceStrings [ "." ] [ "-" ] emacs.name)
    (lib.toPName ename)
  ];

  preferLocalBuild = true;
  allowSubstitutes = false;

  outputs = [ "out" ] ++ lib.optional hasInfoOutput "info";

  buildInputs = [ emacs texinfo ];

  unpackPhase = ''
    for file in ${lib.escapeShellArgs files}
    do
      cp -r $src/$file .
    done
  '';

  buildPhase = ''
    export EMACSLOADPATH="${emacsLoadPath}"

    runHook preBuild

    ${buildCmd}

    ${lib.optionalString hasInfoOutput buildInfo}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    lispDir=$out/share/emacs/site-lisp/elpa/$ename-$version
    install -d $lispDir
    tar cf - --exclude='*.info' . | (cd $lispDir && tar xf -)

    ${lib.optionalString hasInfoOutput installInfo}

    runHook postInstall
  '';

  passthru = {
    inherit elispAttrs;
  };
}
