{ lib
, flakeLockData
, archiveLockData
}:
{ type
, ...
} @ inventory:
with builtins;
let
  args = removeAttrs inventory [ "type" "name" "exclude" ];
in
mode:
removeAttrs
  (
    (if type == "melpa"
    then import ./melpa.nix { inherit lib flakeLockData; }
    else if type == "elpa-core"
    then import ./elpa-core.nix { inherit lib; }
    else if type == "archive"
    then import ./archive.nix { inherit lib archiveLockData; }
    else if type == "gitmodules"
    then import ./gitmodules.nix { inherit lib flakeLockData; }
    else throw "Unsupported inventory type: ${type}")
      args
      mode)
  (inventory.exclude or [ ])
