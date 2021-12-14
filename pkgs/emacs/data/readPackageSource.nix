let
  inherit (builtins) pathExists fetchTree replaceStrings map readDir hasAttr
    readFile attrNames filter all match isString isList typeOf length head;
  globToRegex = replaceStrings [ "?" "*" "." ] [ "." ".*" "\\." ];
in
{ lib
, emacs
, lockFile
}:
let
  inherit (lib) gitignoreSource;

  elpaLispFiles = attrs: src:
    let
      lispDir =
        if attrs ? lisp-dir
        then src + "/${attrs.lisp-dir}"
        else src;

      ignorePatterns = map globToRegex (attrs.ignored-files or [ ]);
    in
    # TODO: Scan the directory recursively.
      #
      # This isn't fatal, as we are mostly interested in lisp files, which is
      # specified in optional :lisp-dir field.
    lib.pipe lispDir [
      readDir
      (lib.filterAttrs (_: type: type == "regular"))
      attrNames
      # FIXME: If :lisp-dir is specified, other files (e.g. doc) are ignored
      (map (file:
        if attrs ? lisp-dir
        then "${attrs.lisp-dir}/${file}"
        else file))
      (filter (file: all (pattern: match pattern file == null) ignorePatterns))
    ];

  elpaDocFiles = attrs:
    if ! attrs ? doc
    then [ ]
    else if isString attrs.doc
    then [ attrs.doc ]
    else if isList attrs.doc
    then attrs.doc
    else throw "The value of :doc must be either a string or alist: ${attrs.doc}";

  elpaFiles = attrs: src:
    lib.unique (elpaLispFiles attrs src ++ elpaDocFiles attrs);

  toLockData = { nodes, version, ... }:
    if version == 7
    then lib.mapAttrs (_: { locked, ... }: locked) nodes
    else throw "Unsupported flake.lock version ${version}";

  lockData =
    if pathExists lockFile
    then toLockData (lib.importJSON lockFile)
    else { };
in
ename:
{ type
, entry
, ...
} @ prescription:
self:
let
  filesInfo =
    if type == "elpa" && entry ? core
    then {
      pure = true;
      inherit (emacs) src;
      files =
        if isString entry.core
        then [ entry.core ]
        else if isList entry.core
        then entry.core
        else throw "Invalid :core value type: ${typeOf entry.core}";
    }
    else {
      pure = hasAttr ename lockData;
      src =
        if self.pure
        then fetchTree lockData.${ename}
        else fetchTree self.origin;
      files =
        if type == "elpa"
        then elpaFiles entry self.src
        else if type == "melpa"
        then lib.expandMelpaRecipeFiles self.src (entry.files or null)
        else throw "FIXME";
      origin =
        if type == "elpa"
        then lib.flakeRefAttrsFromElpaAttrs { preferReleaseBranch = false; } entry
        else if type == "melpa"
        then lib.flakeRefAttrsFromMelpaRecipe entry
        else throw "Unsupported type: ${type}";
    };

  elispFiles = filter (file: match ".+\\.el" file != null) self.files;
  mainFiles = filter (file: baseNameOf file == ename + ".el") elispFiles;

  mainFile =
    if type == "elpa" && entry ? main-file
    then entry.main-file
    else if length mainFiles > 0
    then head mainFiles
    else if length elispFiles > 0
    then head elispFiles
    else throw "Package ${ename} contains no *.el file. See ${self.sourceDir}";

  headers = lib.parseElispHeaders (readFile (self.src + "/${self.mainFile}"));

  metaFromHeaders = import ./meta.nix {
    inherit lib headers;
  };

  pkgFiles = filter (file: baseNameOf file == ename + "-pkg.el") elispFiles;
  pkgFile = head pkgFiles;
  hasPkgFile = length pkgFiles != 0;
  packageDesc =
    if hasPkgFile
    then lib.parsePkg (readFile (self.src + "/${pkgFile}"))
    else { };

  metaFromPackageDesc =
    if hasPkgFile
    then {
      description = packageDesc.summary;
    }
    else { };
in
filesInfo
  //
{
  inherit ename;
  author = headers.Author or null;
  version =
    packageDesc.version
      or headers.Version
      or headers.Package-Version
      # There are packages that lack a version header, so fallback to zero.
      or "0.0.0";
  meta = metaFromHeaders // metaFromPackageDesc;
  inherit mainFile headers;
  packageRequires =
    if packageDesc ? packageRequires
    then packageDesc.packageRequires
    else if self.headers ? Package-Requires
    then lib.parsePackageRequireLines self.headers.Package-Requires
    else { };
  inventory = lib.getAttrs [ "type" "entry" "path" ] prescription;
}
