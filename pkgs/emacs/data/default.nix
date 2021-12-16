let
  inherit (builtins) length head tail hasAttr filter elem mapAttrs readFile
    pathExists concatLists isFunction removeAttrs attrNames;
in
{ lib
, emacs
, builtinLibraries
, inventorySpecs
, lockFile
, inputOverrides
, elispPackagePins
}:
let
  makeInventory = { type, path, ... } @ spec:
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
    else if type == "gitmodules"
    then {
      data = lib.readGitModulesFile path;
    }
    else throw "Unsupported inventory type: ${type}");

  inventories = map makeInventory inventorySpecs;

  findInventoryByName = name:
    lib.findFirst (i: i.name or null == name)
      (throw "There is no inventory named ${name}")
      inventories;

  readMelpaRecipeMaybe = file:
    if pathExists file
    then lib.parseMelpaRecipe (readFile file)
    else null;

  lookupInventory = ename: i @ { type, ... }:
    i
    //
    {
      entry =
        if type == "melpa"
        then readMelpaRecipeMaybe (i.path + "/${ename}")
        else if type == "elpa"
        then i.data.${ename} or null
        else if type == "gitmodules"
        then i.data.${ename} or null
        else throw "FIXME";
    };

  # Like lookupInventory, but throws an error if the entry is not found.
  lookupNamedInventory = ename: name:
    if (lookupInventory ename (findInventoryByName name)).entry == null
    then throw "The inventory named ${name} does not contain a package named ${ename}"
    else lookupInventory ename (findInventoryByName name);

  findPrescription = ename: pin:
    if pin != null
    then lookupNamedInventory ename pin
    else lib.pipe inventories [
      (map (lookupInventory ename))
      (filter ({ entry, ... }: entry != null))
      (results:
        if length results == 0
        then throw "No prescription found for ${ename}"
        else head results)
    ];

  # This recursion produces a deep stack trace. The more packages you have, the
  # more traces it will produce. I want to avoid it, but I don't know how,
  # because Nix doesn't support mutable data structures.
  accumPackage = acc: enames:
    if length enames == 0
    then acc
    else if hasAttr (head enames) acc
    then accumPackage acc (tail enames)
    else
      let
        ename = head enames;
        pin = elispPackagePins.${ename} or null;
        data = lib.makeExtensible (import ./package.nix
          {
            inherit lib emacs lockFile;
          }
          ename
          # It would be nice if it were possible to set the pin from inside
          # overrideInputs, but it causes infinite recursion unfortunately :(
          (findPrescription ename pin));
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
          # Reduce the list as much as possible to keep the stack trace sane.
          (lib.subtractLists
            (builtinLibraries ++ attrNames acc ++ enames)
            (lib.packageRequiresToLibraryNames data'.packageRequires)));

in
accumPackage { }
