let
  inherit
    (builtins)
    length
    head
    tail
    hasAttr
    filter
    elem
    mapAttrs
    readFile
    pathExists
    concatLists
    isFunction
    removeAttrs
    attrNames
    foldl'
    listToAttrs
    ;
in
  {
    lib,
    linkFarm,
    builtinLibraries,
    inventories,
    flakeLockFile,
    archiveLockFile,
    inputOverrides,
    elispPackagePins,
  }: mode: let
    toLockData = {
      nodes,
      version,
      ...
    }:
      if version == 7
      then lib.mapAttrs (_: {locked, ...}: locked) nodes
      else throw "Unsupported flake.lock version ${version}";

    flakeLockData =
      if pathExists flakeLockFile
      then toLockData (lib.importJSON flakeLockFile)
      else {};

    archiveLockData =
      if pathExists archiveLockFile
      then lib.importJSON archiveLockFile
      else {};

    makeInventory = import ./inventory {
      inherit lib flakeLockData archiveLockData;
    };

    inventoryPackageSets =
      map
      (spec: {
        name = spec.name or null;
        value = makeInventory spec mode;
      })
      inventories;

    namedInventories = lib.pipe inventoryPackageSets [
      (filter ({name, ...}: name != null))
      listToAttrs
    ];

    packageData = foldl' (acc: {value, ...}: value // acc) {} inventoryPackageSets;

    findPrescription = ename:
      packageData.${ename} or (throw "Package ${ename} is not found");

    findFromPinned = ename: inventory:
      if hasAttr ename inventory
      then inventory.${ename}
      else if inventory ? _impure
      then inventory._impure.${ename}
      else throw "Package ${ename} does not exist in the pinned inventory";

    findPrescription' = ename: pin:
      if pin == null
      then findPrescription ename
      else
        findFromPinned ename
        (
          namedInventories.${pin}
          or (throw "Inventory named ${pin} does not exist")
        );

    getPackageData = ename:
      lib.makeExtensible (import ./package.nix {inherit lib linkFarm;}
        ename
        # It would be nice if it were possible to set the pin from inside
        # overrideInputs, but it causes infinite recursion unfortunately :(
        (findPrescription' ename (elispPackagePins.${ename} or null)));

    toOverrideFn = overrides:
      if isFunction overrides
      then overrides
      else _: _: overrides;

    getPackageData' = ename:
      lib.pipe
      # Because this extending operation affects which packages are included in the
      # output, it must be done before the entire package set is calculated.
      (
        if hasAttr ename inputOverrides
        then (getPackageData ename).extend (toOverrideFn inputOverrides.${ename})
        else getPackageData ename
      )
      [
        # The user should not call extend after the package set is calculated, so
        # remove it here.
        (lib.flip removeAttrs ["extend"])
        (lib.filterAttrs (_: v: v != null))
      ];

    go = acc: enames: ename: data:
      accumPackage
      (acc // {${ename} = data;})
      (enames
        ++
        # Reduce the list as much as possible to keep the stack trace sane.
        (lib.subtractLists
          (builtinLibraries ++ attrNames acc ++ enames)
          (lib.packageRequiresToLibraryNames data.packageRequires)));

    # This recursion produces a deep stack trace. The more packages you have, the
    # more traces it will produce. I want to avoid it, but I don't know how,
    # because Nix doesn't support mutable data structures.
    accumPackage = acc: enames:
      if length enames == 0
      then acc
      else if hasAttr (head enames) acc
      then accumPackage acc (tail enames)
      else go acc enames (head enames) (getPackageData' (head enames));
  in
    accumPackage {}
