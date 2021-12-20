{ lib
, pkgs
}:
{ emacs ? pkgs.emacs
, flakeLockFile
, archiveLockFile
, inventories
, initFiles
, extraPackages ? [ "use-package" ]
, addSystemPackages ? true
, inputOverrides ? { }
, nativeCompileAheadDefault ? true
}:
let
  inherit (builtins) readFile attrNames attrValues concatLists isFunction
    split filter isString mapAttrs match isList;
in
lib.makeScope pkgs.newScope (self:
  let
    userConfig = lib.pipe self.initFiles [
      (map (file: lib.parseUsePackages (readFile file)))
      lib.zipAttrs
      (lib.mapAttrs (name: values:
        if name == "elispPackages"
        then concatLists values
        else if name == "elispPackagePins"
        then lib.foldl' (acc: x: acc // x) { } values
        else if name == "systemPackages"
        then concatLists values
        else throw "${name} is an unknown attribute"
      ))
    ];

    explicitPackages = userConfig.elispPackages ++ extraPackages;

    builtinLibraryList = self.callPackage ./builtins.nix { };

    builtinLibraries = lib.pipe (readFile builtinLibraryList) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];

    enumerateConcretePackageSet = import ./data {
      inherit lib flakeLockFile archiveLockFile
        builtinLibraries inventories inputOverrides;
      inherit (userConfig) elispPackagePins;
    };

    packageInputs = enumerateConcretePackageSet "build" explicitPackages;

    visibleBuiltinLibraries = lib.subtractLists explicitPackages builtinLibraries;

    allDependencies = lib.fix (self:
      mapAttrs
        (_ename: { packageRequires, ... }:
          let
            explicitDeps = lib.subtractLists visibleBuiltinLibraries
              (lib.packageRequiresToLibraryNames packageRequires);
          in
          lib.unique
            (explicitDeps
              ++ concatLists (lib.attrVals explicitDeps self)))
        packageInputs);

    versionStatus = import ./version-status.nix {
      emacsVersion = emacs.version;
      inherit lib builtinLibraries;
    };
  in
  {
    inherit lib emacs;

    # Expose only for convenience.
    inherit initFiles;

    # Expose for inspecting the configuration. Don't override this attribute
    # using overrideScope', it doesn't affect anything.
    packageInputs = lib.pipe packageInputs [
      (mapAttrs (_: lib.filterAttrs (_: v: ! isFunction v)))
    ];

    versions = versionStatus packageInputs;

    # You cannot use callPackageWith because it will apply makeOverridable
    # which will add extra attributes, e.g. overrideDerivation, to the result.
    # It will make builtins.attrNames unusable to this attribute.
    elispPackages = lib.makeScope self.newScope (eself:
      mapAttrs
        (ename: attrs:
          self.callPackage ./build-elisp.nix { }
            ({
              nativeCompileAhead = nativeCompileAheadDefault;
              elispInputs = lib.attrVals allDependencies.${ename} eself;
            } // attrs))
        packageInputs);

    emacsWrapper = self.callPackage ./wrapper.nix
      {
        elispInputs = lib.attrVals (attrNames packageInputs) self.elispPackages;
        # It may be better to use lib.attrByPath to access packages like
        # gitAndTools.git-lfs, but I am not sure if a path can be safely
        # split by ".".
        executablePackages =
          if addSystemPackages
          then lib.attrVals userConfig.systemPackages pkgs
          else [ ];
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWrapper) name type outputName outPath drvPath;

    flakeNix = {
      description = "THIS IS AN AUTO-GENERATED FILE. PLEASE DON'T EDIT IT MANUALLY.";
      inputs = lib.pipe packageInputs [
        (lib.filterAttrs (_: attrs: attrs ? origin))
        (lib.mapAttrs (_: { origin, ... }: origin // { flake = false; }))
      ];
      outputs = { ... }: { };
    };

    flakeLock = import ./flake-lock.nix {
      inherit lib flakeLockFile packageInputs;
    };

    archiveLock = lib.pipe (enumerateConcretePackageSet "update" explicitPackages) [
      (lib.filterAttrs (_: attrs: attrs ? archive))
      (mapAttrs (_: lib.getAttrs [
        "version"
        "archive"
        "packageRequires"
      ]))
    ];
  })
