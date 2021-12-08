{ lib
, pkgs
}:
{ emacs ? pkgs.emacs
, collectiveDir
, inventorySpecs
, initFiles
, extraPackages ? [ "use-package" ]
, addSystemPackages ? true
, packageOverrides ? { }
}:
let
  inherit (builtins) readFile attrNames attrValues concatLists;

  getBuiltinLibraries = pkgs.callPackage ./packages/builtins.nix { };

  profileElisp = drv @ { passthru, ... }: passthru // { inherit (drv) src; };
in
lib.makeScope pkgs.newScope (self:
  let
    userConfig = lib.pipe self.initFiles [
      (map (file: lib.parseUsePackages (readFile file)))
      lib.zipAttrs
      (lib.mapAttrs (_: concatLists))
    ];
  in
  {
    inherit lib emacs collectiveDir;

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

    inventories = map self.makeInventory inventorySpecs;

    inherit initFiles;
    inherit extraPackages;
    inherit packageOverrides;

    builtinLibraries = getBuiltinLibraries emacs;

    # You cannot use callPackageWith because it will apply makeOverridable
    # which will add extra attributes, e.g. overrideDerivation, to the result.
    # It will make builtins.attrNames unusable to this attribute.
    elispPackages = self.callPackage ./packages
      {
        explicitPackages = userConfig.elispPackages ++ self.extraPackages;
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
          (_: { sourceAttrs, ... }: sourceAttrs // { flake = false; })
          self.packageProfiles;
      outputs = { ... }: {};
    };
  })
