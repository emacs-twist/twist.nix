{
  lib,
  flakeLockData,
}: {type, ...} @ inventory:
with builtins; let
  args = removeAttrs inventory ["type" "name" "exclude"];
in
  mode:
    removeAttrs
    (
      (
        if type == "melpa"
        then import ./melpa.nix {inherit lib flakeLockData;}
        else if type == "elpa"
        then import ./elpa.nix {inherit lib flakeLockData;}
        else if type == "archive-contents"
        then import ./archive-contents.nix {inherit lib flakeLockData;}
        else if type == "gitmodules"
        then import ./gitmodules.nix {inherit lib flakeLockData;}
        else throw "Unsupported inventory type: ${type}"
      )
      args
      mode
    )
    (inventory.exclude or [])
