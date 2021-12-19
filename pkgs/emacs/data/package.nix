let
  inherit (builtins) pathExists fetchTree replaceStrings map readDir hasAttr
    readFile attrNames filter all match isString isList typeOf length head toJSON;
in
{ lib
, emacs
, lockFile
}:
let
  toLockData = { nodes, version, ... }:
    if version == 7
    then lib.mapAttrs (_: { locked, ... }: locked) nodes
    else throw "Unsupported flake.lock version ${version}";

  nonCoreSourceInfo = import ./source.nix {
    inherit lib;
    lockData =
      if pathExists lockFile
      then toLockData (lib.importJSON lockFile)
      else { };
  };
in
ename:
{ type
, entry
, ...
} @ prescription:
self:
let
  elispFiles = filter (file: match ".+\\.el" file != null) self.files;
  mainFiles = filter (file: baseNameOf file == ename + ".el") elispFiles;

  mainFile =
    if type == "elpa" && entry ? main-file
    then entry.main-file
    else if length mainFiles > 0
    then head mainFiles
    else if length elispFiles > 0
    then head elispFiles
    else throw ''
           Package ${ename} contains no *.el file.
           Check the contents in the store: ${self.src}
           Files: ${toJSON self.files}
           Entry: ${toJSON entry}
         '';

  # builtins.readFile fails when the source file contains control characters.
  # pydoc.el is an example. A workaround is to take only the first N bytes of
  # the file using `head` command and read its output.
  headers = lib.parseElispHeaders
    (lib.readFirstBytes
      # magit.el has a relatively long header, so other libraries would be shorter.
      (self.headerLengthLimit or 1500)
      (self.src + "/${self.mainFile}"));

  pkgFiles = filter (file: baseNameOf file == ename + "-pkg.el") elispFiles;
  pkgFile = head pkgFiles;
  hasPkgFile = length pkgFiles != 0;
  packageDesc =
    if hasPkgFile
    then lib.parsePkg (readFile (self.src + "/${pkgFile}"))
    else { };
in
(if type == "elpa" && entry ? core
then {
  pure = true;
  inherit (emacs) src;
  files =
    if isString entry.core
    then [ entry.core ]
    else if isList entry.core
    then entry.core
    else throw "Invalid core value type: ${typeOf entry.core}";
  origin = {
    type = "github";
    owner = "emacs-mirror";
    repo = "emacs";
  };
} else
  nonCoreSourceInfo self {
    inherit ename type entry;
  })
  //
{
  inherit ename;
  inherit elispFiles;
  author = headers.Author or null;
  version =
    packageDesc.version
      or headers.Version
      or headers.Package-Version
      # There are packages that lack a version header, so fallback to zero.
      or "0.0.0";
  meta =
    (import ./headers-to-meta.nix {
      inherit lib headers;
    })
    //
    (lib.optionalAttrs hasPkgFile {
      description = packageDesc.summary;
    });
  inherit mainFile headers;
  packageRequires =
    if packageDesc ? packageRequires
    then packageDesc.packageRequires
    else if self.headers ? Package-Requires
    then lib.parsePackageRequireLines self.headers.Package-Requires
    else { };
  inventory = lib.getAttrs [ "type" "entry" "path" ] prescription;
}
