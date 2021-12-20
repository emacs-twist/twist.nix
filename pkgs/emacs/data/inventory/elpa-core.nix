{ lib }:
with builtins;
{ path
, src
}:
_mode:
lib.pipe (readFile path) [
  lib.parseElpaPackages
  (lib.filterAttrs (_: args: args ? core))
  (lib.mapAttrs (_: { core, ... } @ entry:
    {
      inherit src;
      customUnpackPhase = true;
      files =
        if isString core
        then [ core ]
        else core;
      inherit entry;
    }
  ))
]
