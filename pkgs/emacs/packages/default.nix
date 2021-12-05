{ lib
, emacs
, builtinLibraries
, inventories
, collectiveDir
, explicitPackages
, stdenv
}:
let
  inherit (builtins) length head tail hasAttr filter elem mapAttrs readFile
    pathExists concatLists;

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
        data = lib.fix (import ./readPackageSource.nix
          {
            inherit lib emacs collectiveDir;
          }
          ename
          prescription);
      in
      accumPackage
        (acc // { ${ename} = data; })
        (enames
          ++
          (filter
            (ename: !elem ename builtinLibraries)
            data.packageRequires));

  enabledPackages = accumPackage { } explicitPackages;

  visibleBuiltinLibraries = lib.subtractLists explicitPackages builtinLibraries;

  # Collect implicit dependencies.
  requiredPackageSet = lib.fix (depsFrom: mapAttrs
    (_ename: { packageRequires, ... }:
      let
        explicitDeps = lib.subtractLists visibleBuiltinLibraries packageRequires;
      in
      lib.unique
        (explicitDeps
          ++
          concatLists
            (lib.attrVals explicitDeps depsFrom)))
    enabledPackages);
in
self:
# Annotate a concrete set of elisp dependencies (including implicit ones) to each package.
mapAttrs
  (ename:
    { meta
    , ...
    } @ data:
    let
      requiredPackages = requiredPackageSet.${ename};

      derivation = lib.callPackageWith data ./buildElispPackage.nix
        {
          inherit ename;
          elispDerivations = lib.attrVals requiredPackages self.elispPackages;
        }
        {
          inherit lib stdenv emacs;
        };

      data' = data // {
        inherit requiredPackages;
      };
    in
    lib.extendDerivation true
      {
        inherit meta;
        # Remove attributes that can't be serialized into JSON.
        passthru = removeAttrs data' [ "src" ];
      }
      derivation
  )
  enabledPackages
