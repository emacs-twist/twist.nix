{
  lib,
  runCommand,
  texinfo,
}:
{
  ename,
  version ? null,
  meta,
  sourceInfo ? null,
  packageRequires,
  # There are some missing attributes desired for the package description, but
  # omit them for now.
  ...
}:
drv:
let
  attrsToLispAlist =
    attrs:
    "("
    + lib.pipe attrs [
      (lib.mapAttrsToList (name: value: "(${name} \"${value}\")"))
      (builtins.concatStringsSep " ")
    ]
    + ")";

  hasInfo = builtins.elem "info" drv.outputs;

  commitInfo = lib.optionalString (sourceInfo != null && sourceInfo ? rev) ''
    :commit "${sourceInfo.rev}"
  '';

  versionString = if version != null then version else "0";
in
runCommand "${ename}-${versionString}"
  {
    buildInputs = lib.optional hasInfo texinfo;

    pkgDescription = ''
      (define-package "${ename}" "${versionString}" "${meta.description}"
        '${attrsToLispAlist (builtins.mapAttrs (_: v: if v != null then v else "0") packageRequires)}
        ${commitInfo})
      ;; Local Variables:
      ;; no-byte-compile: t
      ;; End:
    '';

    passAsFile = [ "pkgDescription" ];
  }
  ''
    mkdir $out
    cd $out
    install -m 644 $pkgDescriptionPath ${ename}-pkg.el
    ${lib.optionalString hasInfo ''
      if [[ -d ${drv.info}/share/info ]]
      then
        shopt -s nullglob
        for i in ${drv.info}/share/info/*.info ${drv.info}/share/info/*.info.gz
        do
          install -m 644 -t . $i
          install-info $(basename $i) $out/dir
        done
      fi
    ''}
    (cd ${drv.outPath}/share/emacs/site-lisp \
     && tar cf - \
        --exclude='*-autoloads.el' \
        .) | tar xf -
  ''
