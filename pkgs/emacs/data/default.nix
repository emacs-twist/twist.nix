let
  inherit (builtins) length head tail hasAttr filter elem mapAttrs readFile
    pathExists concatLists isFunction removeAttrs;
in
{ lib
, emacs
, builtinLibraries
, inventorySpecs
, lockFile
, inputOverrides
}:
let
  makeInventory = { type, path } @ spec:
    spec
    //
    (if type == "melpa"
    then { }
    else if type == "elpa"
    then {
      data = lib.filterAttrs
        (_: args: args ? core || args.url != null)
        (lib.parseElpaPackages (readFile path));
    }
    else throw "Unsupported inventory type: ${type}");

  inventories = map makeInventory inventorySpecs;

  readMelpaRecipeMaybe = file:
    if pathExists file
    then lib.parseMelpaRecipe (readFile file)
    else null;

  findPrescription = ename: lib.pipe inventories [
    (map (i @ { type, ... }:
      (i // {
        entry =
          if type == "melpa"
          then readMelpaRecipeMaybe (i.path + "/${ename}")
          else if type == "elpa"
          then i.data.${ename} or null
          else throw "FIXME";
      })))
    (filter ({ entry, ... }: entry != null))
    (results:
      if length results == 0
      then throw "No prescription found for ${ename}"
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
        toOverrideFn = overrides:
          if isFunction overrides
          then overrides
          else _: _: overrides;
        # Because this extending operation affects which packages are included
        # in the output, it must be done here.
        data' =
          if hasAttr ename inputOverrides
          then data.extend (toOverrideFn inputOverrides.${ename})
          else data;
      in
      accumPackage
        # You should not call extend afterwards, so remove it here.
        (acc // { ${ename} = removeAttrs data' [ "extend" ]; })
        (enames
          ++
          (filter
            (ename: !elem ename builtinLibraries)
            (lib.packageRequiresToLibraryNames data'.packageRequires)));

in
accumPackage { }
