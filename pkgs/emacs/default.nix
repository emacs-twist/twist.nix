{ lib
, pkgs
}:
{ emacs ? pkgs.emacs
, lockFile
, inventorySpecs
, initFiles
, extraPackages ? [ "use-package" ]
, addSystemPackages ? true
, packageOverrides ? { }
, nativeCompileAheadDefault ? true
}:
let
  inherit (builtins) readFile attrNames attrValues concatLists isFunction;

  getBuiltinLibraries = pkgs.callPackage ./packages/builtins.nix { };

  profileElisp = { passthru, ... }: lib.pipe passthru.elispAttrs [
    (lib.filterAttrs (_: v: ! isFunction v))
  ];
in
lib.makeScope pkgs.newScope (self:
  let
    userConfig = lib.pipe self.initFiles [
      (map (file: lib.parseUsePackages (readFile file)))
      lib.zipAttrs
      (lib.mapAttrs (_: concatLists))
    ];

    makeInventory = { type, path }:
      { inherit type; }
      //
      (if type == "melpa"
       then { inherit path; }
       else if type == "elpa"
       then {
         data = lib.filterAttrs
           (_: args: args ? core || args.url != null)
           (lib.parseElpaPackages (readFile path));
       }
       else throw "Unsupported inventory type: ${type}");
  in
  {
    inherit lib emacs;

    # Expose only for convenience.
    inherit initFiles;

    # You cannot use callPackageWith because it will apply makeOverridable
    # which will add extra attributes, e.g. overrideDerivation, to the result.
    # It will make builtins.attrNames unusable to this attribute.
    elispPackages = import ./packages
      {
        inherit (pkgs) stdenv;
        inherit lib emacs lockFile packageOverrides nativeCompileAheadDefault;
        explicitPackages = userConfig.elispPackages ++ extraPackages;
        inventories = map makeInventory inventorySpecs;
        builtinLibraries = getBuiltinLibraries emacs;
      }
      self;

    emacsWithPackages = self.callPackage ./wrapper.nix
      {
        elispPackages = attrValues self.elispPackages;
        # It may be better to use lib.attrByPath to access packages like
        # gitAndTools.git-lfs, but I am not sure if a path can be safely
        # split by ".".
        executablePackages =
          if addSystemPackages
          then lib.attrVals userConfig.systemPackages pkgs
          else [ ];
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWithPackages) name type outputName outPath drvPath;

    # Expose the package information to the user via `nix eval`.
    packageProfiles = lib.pipe self.elispPackages [
      (lib.mapAttrs (_: profileElisp))
    ];

    flakeNix = {
      description = "This is an auto-generated file. Please don't edit it manually.";
      inputs =
        lib.mapAttrs
          (_: { origin, ... }: origin // { flake = false; })
          self.packageProfiles;
      outputs = { ... }: {};
    };

    flakeLock = import ./packages/lock.nix {
      inherit lib lockFile;
      inherit (self) elispPackages;
    };
  })
