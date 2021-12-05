let
  inherit (builtins) pathExists fetchTree replaceStrings map readDir
    readFile attrNames filter all match isString isList typeOf length head;
  globToRegex = replaceStrings [ "?" "*" "." ] [ "." ".*" "\\." ];
in
{ lib
, emacs
, collectiveDir
}:
let
  inherit (lib) gitignoreSource;

  elpaFiles = attrs: src:
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
      (map (file:
        if attrs ? lisp-dir
        then "${attrs.lisp-dir}/${file}"
        else file))
      (filter (file: all (pattern: match pattern file == null) ignorePatterns))
    ];
in
ename:
{ type
, entry
}:
self:
let
  localSrc = collectiveDir + "/${ename}";

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
      pure = collectiveDir != null && pathExists localSrc;
      src =
        if self.pure
        then gitignoreSource localSrc
        else fetchTree self.sourceAttrs;
      files =
        if type == "elpa"
        then elpaFiles entry self.src
        else if type == "melpa"
        then lib.expandMelpaRecipeFiles self.src (entry.files or null)
        else throw "FIXME";
      sourceAttrs =
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

  meta = import ./meta.nix {
    inherit lib headers;
  };
in
filesInfo
//
meta
  //
{
  inherit mainFile headers;
  packageRequires =
    if self.headers ? Package-Requires
    then
      lib.pipe self.headers.Package-Requires [
        lib.parsePackageRequireLines
        attrNames
        (filter (name: name != "emacs"))
      ]
    else [ ];
}
