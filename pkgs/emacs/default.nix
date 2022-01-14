{ lib
, pkgs
, final
}:
{ emacsPackage ? pkgs.emacs
, lockDir
, inventories
, initFiles
, initParser ? lib.parseUsePackages
, extraPackages ? [ "use-package" ]
, addSystemPackages ? true
, inputOverrides ? { }
, nativeCompileAheadDefault ? true
, extraOutputsToInstall ? [ "info" ]
}:
let
  inherit (builtins) readFile attrNames attrValues concatLists isFunction
    split filter isString mapAttrs match isList;
in
lib.makeScope pkgs.newScope (self:
  let
    flakeLockFile = lockDir + "/flake.lock";

    archiveLockFile = lockDir + "/archive.lock";

    userConfig = lib.pipe self.initFiles [
      (map (file: initParser (readFile file)))
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

    explicitPackages = (userConfig.elispPackages or [ ]) ++ extraPackages;

    builtinLibraryList = self.callPackage ./builtins.nix { };

    builtinLibraries = lib.pipe (readFile builtinLibraryList) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];

    enumerateConcretePackageSet = import ./data {
      inherit lib flakeLockFile archiveLockFile
        builtinLibraries inventories inputOverrides;
      elispPackagePins = userConfig.elispPackagePins or { };
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

    depsCheck = self.callPackage ./tools/check-versions.nix
      {
        emacsVersion = emacsPackage.version;
        inherit lib builtinLibraries;
      }
      packageInputs;

    generateLockFiles = self.callPackage ./lock {
      inherit flakeLockFile;
    };
  in
  {
    inherit lib;
    emacs = emacsPackage;

    # Expose only for convenience.
    inherit initFiles;

    # Expose for inspecting the configuration. Don't override this attribute
    # using overrideScope', it doesn't affect anything.
    packageInputs = lib.pipe packageInputs [
      (mapAttrs (_: attrs:
        lib.filterAttrs (_: v: ! isFunction v)
          (attrs // lib.optionalAttrs (attrs.src ? lastModified) {
            inherit (attrs.src) lastModified;
          })
      ))
    ];

    inherit depsCheck;

    # You cannot use callPackageWith because it will apply makeOverridable
    # which will add extra attributes, e.g. overrideDerivation, to the result.
    # It will make builtins.attrNames unusable to this attribute.
    elispPackages = lib.makeScope self.newScope (eself:
      mapAttrs
        (ename: attrs:
          self.callPackage ./build { }
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
          then lib.attrVals (userConfig.systemPackages or [ ]) final
          else [ ];
        inherit extraOutputsToInstall;
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWrapper) name type outputName outPath drvPath;

    admin = lockDirName: {
      # Generate flake.nix and archive.lock with a complete package set. You
      # have to run `nix flake lock`` in the target directory to update
      # flake.lock.
      lock = generateLockFiles {
        packageInputs = enumerateConcretePackageSet "lock" explicitPackages;
        flakeNix = true;
        archiveLock = true;
        postCommand = "nix flake lock";
      } lockDirName;

      # Generate flake.lock with the current revisions
      #
      # sync = generateLockFiles {
      #   inherit packageInputs;
      #   flakeLock = true;
      # };

      # Generate archive.lock with latest packages from ELPA package archives
      update = generateLockFiles {
        packageInputs = enumerateConcretePackageSet "update" explicitPackages;
        archiveLock = true;
      } lockDirName;
    };
  })
