{ lib, stdenv, emacs, elispPackages }:
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
  inherit (builtins) concatStringsSep replaceStrings;

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

in
stdenv.mkDerivation {
  inherit src ename meta version;

  pname = concatStringsSep "-" [
    (replaceStrings [ "." ] [ "-" ] emacs.name)
    (lib.toPName ename)
  ];

  preferLocalBuild = true;
  allowSubstitutes = false;

  buildInputs = [ emacs ];

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

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    lispDir=$out/share/emacs/site-lisp/elpa/$ename-$version
    install -d $lispDir
    tar cf - . | (cd $lispDir && tar xf -)

    runHook postInstall
  '';

  passthru = {
    inherit elispAttrs;
  };
}
