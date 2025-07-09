let
  inherit
    (builtins)
    length
    head
    tail
    hasAttr
    filter
    pathExists
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
    metadataJsonFile,
    inputOverrides,
    elispPackagePins,
    defaultMainIsAscii,
    persistMetadata,
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

    cachedMetadata =
      if mode == "build" && persistMetadata && pathExists metadataJsonFile
      then lib.importJSON metadataJsonFile
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

    findPrescription = revDep: ename:
      packageData.${ename}
      or (
        if revDep == null
        then throw "Package ${ename} is not found"
        else throw "Package ${ename} required by ${revDep} is not found"
      );

    findFromPinned = revDep: ename: inventory:
      if hasAttr ename inventory
      then inventory.${ename}
      else if inventory ? _impure
      then inventory._impure.${ename}
      else throw "Package ${ename} required by ${revDep} does not exist in the pinned inventory";

    findPrescription' = revDep: ename: pin:
      if pin == null
      then findPrescription revDep ename
      else
        findFromPinned revDep ename
        (
          namedInventories.${pin}
          or (throw "Inventory named ${pin} does not exist")
        );

    getPackageData0 =
      import ./package.nix {inherit lib linkFarm defaultMainIsAscii cachedMetadata;};

    getPackageData = revDep: ename:
      lib.makeExtensible (getPackageData0
        ename
        # It would be nice if it were possible to set the pin from inside
        # overrideInputs, but it causes infinite recursion unfortunately :(
        (findPrescription' revDep ename (elispPackagePins.${ename} or null)));

    toOverrideFn = overrides:
      if isFunction overrides
      then overrides
      else _: _: overrides;

    getPackageData' = revDep: ename:
      lib.pipe
      # Because this extending operation affects which packages are included in the
      # output, it must be done before the entire package set is calculated.
      (
        if hasAttr ename inputOverrides
        then (getPackageData revDep ename).extend (toOverrideFn inputOverrides.${ename})
        else getPackageData revDep ename
      )
      [
        # The user should not call extend after the package set is calculated, so
        # remove it here.
        (lib.flip removeAttrs ["extend"])
        (lib.filterAttrs (_: v: v != null))
      ];

    go = acc: revDeps: enames: ename: data:
      accumPackage
      (acc // {${ename} = data;})
      (revDeps
        // lib.pipe (lib.packageRequiresToLibraryNames data.packageRequires) [
          (map (name: {
            inherit name;
            value = ename;
          }))
          listToAttrs
        ])
      (enames
        ++
        # Reduce the list as much as possible to keep the stack trace sane.
        (lib.subtractLists
          (builtinLibraries ++ attrNames acc ++ enames)
          (lib.packageRequiresToLibraryNames data.packageRequires)));

    # This recursion produces a deep stack trace. The more packages you have, the
    # more traces it will produce. I want to avoid it, but I don't know how,
    # because Nix doesn't support mutable data structures.
    accumPackage = acc: revDeps: enames:
      if length enames == 0
      then acc
      else if hasAttr (head enames) acc
      then accumPackage acc revDeps (tail enames)
      else
        go acc revDeps enames (head enames)
        # It would be better if builtins.addErrorContext worked without --show-trace
        # option, but that is not the case. For now, we pass down the reverse
        # dependency context to every call of getPackageData, getPackageData,
        # findPrescription, and findPrescription'.
        (getPackageData'
          (revDeps.${head enames} or null)
          (head enames));
  in
    accumPackage {} {}
