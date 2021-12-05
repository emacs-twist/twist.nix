{ ename
, src
, version
, files
, elispDerivations
, meta
, allowErrors ? { }
}:
{ lib, stdenv, emacs }:
let
  inherit (builtins) concatStringsSep replaceStrings;

  pname = concatStringsSep "-" [
    (replaceStrings [ "." ] [ "-" ] emacs.name)
    (lib.toPName ename)
  ];

  allowByteCompileError = allowErrors.byteCompile or false;

  envCmd = ''
    export EMACSLOADPATH="${lib.makeSearchPath "share/emacs/site-lisp" elispDerivations}:"
  '';

  buildCmd = ''
    if ! emacs --batch -L . -f batch-byte-compile *.el
    then
      if [[ "${lib.boolToString allowByteCompileError}" = true ]]
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

  customBuild = stdenv.mkDerivation {
    inherit src;
    inherit pname;
    inherit ename;
    version = lib.makeSourceVersion version src;

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
      ${envCmd}

      runHook preBuild

      ${buildCmd}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      lispDir=$out/share/emacs/site-lisp
      install -d $lispDir
      tar cf - . | (cd $lispDir && tar xf -)

      runHook postInstall
    '';

  };
in
customBuild
