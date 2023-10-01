# Reverse dependencies of elisp packages
{lib}: packageInputs: let
  inherit (builtins) attrNames hasAttr mapAttrs substring;

  revDeps = name:
    lib.concatMapAttrs (
      dependent: {packageRequires, ...}: let
        version = packageRequires.${name} or null;
      in
        if version == null
        then {}
        else {"${dependent}" = version;}
    )
    packageInputs;
in
  mapAttrs (name: {
    version ? null,
    src,
    ...
  }: (
    {
      inherit name version;
      revDeps = revDeps name;
    }
    // (
      if src ? lastModifiedDate
      then {lastModifiedDate = substring 0 8 src.lastModifiedDate;}
      else {}
    )
  ))
  packageInputs
