{ lib }:
with builtins;
{ path
, core-src
} @ args:
_mode:
lib.pipe (readFile path) [
  lib.parseElpaPackages
  (lib.filterAttrs (_: entry: entry ? core))
  (lib.mapAttrs (_: { core, ... } @ entry:
    {
      src = core-src;
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
