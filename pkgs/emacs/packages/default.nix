{ lib
, emacs
, builtinLibraries
, inventories
, lockFile
, explicitPackages
, stdenv
, packageOverrides
, nativeCompileAheadDefault
}:
let
  inherit (builtins) length head tail hasAttr filter elem mapAttrs readFile
    pathExists concatLists isFunction;

  readMelpaRecipeMaybe = file:
    if pathExists file
    then lib.parseMelpaRecipe (readFile file)
    else null;

  findPrescription = ename: lib.pipe inventories [
    (map (i @ { type, ... }:
      {
        inherit type;
        entry =
          if type == "melpa"
          then readMelpaRecipeMaybe (i.path + "/${ename}")
          else if type == "elpa"
          then i.data.${ename} or null
          else throw "FIXME";
      }))
    (filter ({ entry, ... }: entry != null))
    (results:
      if length results == 0
      then "No prescription found for ${ename}"
      else head results)
  ];

  accumPackage = acc: enames:
    if length enames == 0
    then acc
    else if hasAttr (head enames) acc
    then accumPackage acc (tail enames)
    else
      let
        ename = head enames;
        prescription = findPrescription ename;
        data = lib.makeExtensible (import ./readPackageSource.nix
          {
            inherit lib emacs lockFile;
          }
          ename
          prescription);
        data' =
          if hasAttr ename packageOverrides
          then data.extend(packageOverrides.${ename})
          else data;
      in
      accumPackage
        (acc // { ${ename} = data'; })
        (enames
          ++
          (filter
            (ename: !elem ename builtinLibraries)
            data'.packageRequires));

  enabledPackages = accumPackage { } explicitPackages;

  visibleBuiltinLibraries = lib.subtractLists explicitPackages builtinLibraries;

  # Collect implicit dependencies.
  allDependencies = lib.fix
    (deps:
      mapAttrs
        (ename: { packageRequires, ... }:
          let
            explicitDeps = lib.subtractLists visibleBuiltinLibraries packageRequires;
          in
            lib.unique (explicitDeps ++ concatLists (lib.attrVals explicitDeps deps)))
        enabledPackages);
in
self:
mapAttrs
  (ename: attrs:
    self.callPackage ./buildElispPackage.nix { }
      ({
        nativeCompileAhead = nativeCompileAheadDefault;
        requiredPackages = allDependencies.${ename};
      } // attrs))
  enabledPackages
