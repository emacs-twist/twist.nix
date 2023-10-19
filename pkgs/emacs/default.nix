{
  lib,
  pkgs,
  final,
}: {
  emacsPackage ? pkgs.emacs,
  lockDir,
  inventories,
  initFiles,
  initParser ? lib.parseUsePackages {},
  initReader ? file: initParser (builtins.readFile file),
  extraPackages ?
    if builtins.compareVersions emacsPackage.version "29" > 0
    then []
    else ["use-package"],
  addSystemPackages ? true,
  inputOverrides ? {},
  nativeCompileAheadDefault ? true,
  wantExtraOutputs ? true,
  extraOutputsToInstall ?
    if wantExtraOutputs
    then ["info"]
    else [],
  # Export a manifest file of of the package set from the wrapper
  # (experimental). Needed if you use the hot-reloading feature of twist.el.
  exportManifest ? false,
  configurationRevision ? null,
}: let
  inherit
    (builtins)
    readFile
    attrNames
    attrValues
    concatLists
    isFunction
    split
    filter
    isString
    mapAttrs
    match
    isList
    isAttrs
    elem
    ;
in
  lib.makeScope pkgs.newScope (self: let
    flakeLockFile = lockDir + "/flake.lock";

    archiveLockFile = lockDir + "/archive.lock";

    userConfig = lib.pipe self.initFiles [
      (map initReader)
      lib.zipAttrs
      (lib.mapAttrs (
        name: values:
          if name == "elispPackages"
          then concatLists values
          else if name == "elispPackagePins"
          then lib.foldl' (acc: x: acc // x) {} values
          else if name == "systemPackages"
          then concatLists values
          else throw "${name} is an unknown attribute"
      ))
    ];

    explicitPackages = (userConfig.elispPackages or []) ++ extraPackages;

    builtinLibraryList = self.callPackage ./builtins.nix {};

    builtinLibraries = lib.pipe (readFile builtinLibraryList.outPath) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];

    enumerateConcretePackageSet = import ./data {
      inherit (pkgs) linkFarm;
      inherit
        lib
        flakeLockFile
        archiveLockFile
        builtinLibraries
        inventories
        inputOverrides
        ;
      elispPackagePins = userConfig.elispPackagePins or {};
    };

    packageInputs = enumerateConcretePackageSet "build" explicitPackages;

    visibleBuiltinLibraries = lib.subtractLists explicitPackages builtinLibraries;

    allDependencies = lib.fix (self:
      mapAttrs
      (_ename: {packageRequires, ...}: let
        explicitDeps =
          lib.subtractLists visibleBuiltinLibraries
          (lib.packageRequiresToLibraryNames packageRequires);
      in
        lib.unique
        (explicitDeps
          ++ concatLists (lib.attrVals explicitDeps self)))
      packageInputs);

    depsCheck =
      self.callPackage ./tools/check-versions.nix
      {
        emacsVersion = emacsPackage.version;
        inherit lib builtinLibraries;
      }
      packageInputs;

    revDeps =
      self.callPackage ./tools/reverse.nix
      {
        inherit lib;
      }
      packageInputs;

    generateLockFiles = self.callPackage ./lock {
      inherit flakeLockFile;
    };
  in {
    inherit lib;
    emacs = emacsPackage;

    # Exposed only for convenience.
    inherit initFiles;

    # Exposed for inspecting the configuration. Don't override this attribute
    # using overrideScope'. It won't affect anything.
    packageInputs = lib.pipe packageInputs [
      (mapAttrs (
        _: attrs:
          lib.filterAttrs (_: v: ! isFunction v)
          (attrs
            // lib.optionalAttrs (isAttrs attrs.src && attrs.src ? rev) {
              sourceInfo =
                lib.filterAttrs
                  (name: _: elem name [
                    "lastModified"
                    "lastModifiedDate"
                    "narHash"
                    "rev"
                    "shortRev"
                  ])
                  attrs.src;
            })
      ))
    ];

    inherit builtinLibraryList;
    inherit depsCheck revDeps;

    maskedBuiltins =
      lib.intersectLists builtinLibraries (attrNames packageInputs);

    # An actual derivation set of Emacs Lisp packages. You can override this
    # attribute set to change how they are built.
    elispPackages = lib.makeScope self.newScope (eself:
      mapAttrs
      (ename: attrs:
        self.callPackage ./build {}
        ({
            nativeCompileAhead = nativeCompileAheadDefault;
            elispInputs = lib.attrVals allDependencies.${ename} eself;
            inherit wantExtraOutputs;
          }
          // attrs))
      packageInputs);

    # nixpkgs used in elisp build overrides. It is not meant to be overridden by
    # the user.
    pkgs = final;

    executablePackages =
      if addSystemPackages
      then
        map
        (pathStr:
          lib.getAttrFromPath
          (filter isString (split "\\." pathStr))
          final)
        (userConfig.systemPackages or [])
      else [];

    icons = self.callPackage ./icons.nix {};

    emacsWrapper =
      self.callPackage ./wrapper.nix
      {
        packageNames = attrNames packageInputs;
        inherit extraOutputsToInstall exportManifest configurationRevision;
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWrapper) name type outputName outPath drvPath;

    makeApps = {lockDirName}: {
      # Generate flake.nix and archive.lock with a complete package set. You
      # have to run `nix flake lock`` in the target directory to update
      # flake.lock.
      lock =
        generateLockFiles
        {
          packageInputs = enumerateConcretePackageSet "lock" explicitPackages;
          flakeNix = true;
          archiveLock = true;
          postCommand = "nix flake lock";
        }
        lockDirName;

      # Generate flake.lock with the current revisions
      #
      # sync = generateLockFiles {
      #   inherit packageInputs;
      #   flakeLock = true;
      # };

      # Generate archive.lock with latest packages from ELPA package archives
      update =
        generateLockFiles
        {
          packageInputs = enumerateConcretePackageSet "update" explicitPackages;
          archiveLock = true;
        }
        lockDirName;
    };
  })
