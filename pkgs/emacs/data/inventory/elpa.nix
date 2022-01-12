{ lib }:
with builtins;
{ path
, ...
} @ args:
let
  elpaEntries = lib.parseElpaPackages (readFile path);

  corePackages =
    if args ? core-src
    then
      lib.pipe elpaEntries [
        (lib.filterAttrs (_: entry: entry ? core))
        (lib.mapAttrs (_: { core, ... } @ entry:
          {
            src = args.core-src;
            customUnpackPhase = true;
            files =
              if isString core
              then [ core ]
              else core;
            inventory = {
              type = "elpa";
            } // args;
          }
        ))
      ]
    else { };
in
_mode:
corePackages
