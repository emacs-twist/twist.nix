{
  lib,
  pkgs,
  final,
}: {
  emacsPackage ? pkgs.emacs,
  lockDir,
  inventories ? null,
  registries ?
    if inventories == null
    then builtins.abort "emacsTwist: registries is a required argument"
    else lib.warn "emacsTwist: inventories is deprecated. Use registries instead." inventories,
  initFiles,
  initParser ? lib.parseUsePackages {},
  initReader ? file: initParser (builtins.readFile file),
  extraPackages ?
    if builtins.compareVersions emacsPackage.version "29" > 0
    then []
    else ["use-package"],
  # List of package names that are supposed to be reside in the same repository.
  # These packages won't be declared in the generated flake.nix to not produce
  # meaningless diffs in flake.lock.
  localPackages ? [],
  # Commands to run after running generateLockDir. The command is run at the
  # root of the Git repository containing the lock directory. For example, if
  # you have added the lock directory as a subflake, you can run `nix flake update
  # <input name>` (since Nix 2.19) to update the flake input.
  postCommandOnGeneratingLockDir ? null,
  # User-provided list of Emacs built-in libraries as a string list
  initialLibraries ? null,
  addSystemPackages ? true,
  inputOverrides ? {},
  nativeCompileAheadDefault ? true,
  wantExtraOutputs ? true,
  extraOutputsToInstall ?
    if wantExtraOutputs
    then ["info"]
    else [],
  # Whether to persist package metadata in the lock directory. This is needed to
  # avoid IFD in certain situations.
  persistMetadata ? false,
  # Assume the main files of all packages contain only ASCII characters. This is
  # a requirement for avoiding IFD, but some libraries actually contain
  # non-ASCII characters, which cannot be parsed with `builtins.readFile`
  # function of Nix.
  defaultMainIsAscii ? false,
  # Export a manifest file of of the package set from the wrapper
  # (experimental). Needed if you use the hot-reloading feature of twist.el.
  exportManifest ? false,
  configurationRevision ? null,
  extraSiteStartElisp ? "",
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
    removeAttrs
    ;
in
  lib.makeScope pkgs.newScope (self: let
    flakeLockFile = lockDir + "/flake.lock";

    archiveLockFile = lockDir + "/archive.lock";

    metadataJsonFile = lockDir + "/metadata.json";

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

    builtinLibraries =
      if initialLibraries != null
      then initialLibraries
      else
        lib.pipe (readFile builtinLibraryList) [
          (split "\n")
          (filter (s: isString s && s != ""))
        ];

    enumerateConcretePackageSet = import ./data {
      inherit (pkgs) linkFarm;
      inherit
        lib
        flakeLockFile
        archiveLockFile
        metadataJsonFile
        builtinLibraries
        inputOverrides
        defaultMainIsAscii
        persistMetadata
        ;
      # Just remap the name
      inventories = registries;
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

    excludeLocalPackages = attrs: removeAttrs attrs localPackages;
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
                (name: _:
                  elem name [
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
        inherit extraOutputsToInstall exportManifest configurationRevision extraSiteStartElisp;
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWrapper) name type outputName outPath drvPath;

    # A package/derivation for a command that accepts a directory as an argument
    # and write lock files to it
    generateLockDir =
      (generateLockFiles {
        packageInputs =
          excludeLocalPackages (enumerateConcretePackageSet "update" explicitPackages);
        flakeNix = true;
        archiveLock = true;
        metadataJson = persistMetadata;
      })
      .writerScript {inherit postCommandOnGeneratingLockDir;};

    makeApps = {lockDirName}: {
      # Generate flake.nix and archive.lock with a complete package set. You
      # have to run `nix flake lock`` in the target directory to update
      # flake.lock.
      lock =
        (generateLockFiles
          {
            packageInputs =
              excludeLocalPackages (enumerateConcretePackageSet "lock" explicitPackages);
            flakeNix = true;
            archiveLock = true;
            metadataJson = persistMetadata;
            postCommand = "nix flake lock";
          })
        .asAppWritingToRelativeDir
        lockDirName;

      # Generate archive.lock with latest packages from ELPA package archives
      update =
        (generateLockFiles
          {
            packageInputs =
              excludeLocalPackages (enumerateConcretePackageSet "update" explicitPackages);
            archiveLock = true;
            metadataJson = persistMetadata;
          })
        .asAppWritingToRelativeDir
        lockDirName;
    };
  })
