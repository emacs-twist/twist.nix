{
  lib,
  flakeLockData,
}:
with builtins; let
  fromEntry = inventory: {ename, ...} @ entry: self: {
    src =
      if hasAttr ename flakeLockData
      then fetchTree flakeLockData.${ename}
      else
        trace "Impure input for package ${ename} (in melpa.nix): ${toJSON self.origin}"
        (fetchTree self.origin);
    doTangle = true;
    files = lib.expandMelpaRecipeFiles self.src (entry.files or null);
    origin = lib.flakeRefAttrsFromMelpaRecipe entry;
    inventory = inventory // {inherit entry;};
  };
in
  {path}: let
    inventory = {
      type = "melpa";
      inherit path;
    };
  in
    _mode:
      lib.pipe (readDir path) [
        (lib.filterAttrs (_: type: type == "regular"))
        (mapAttrs
          (ename: _: (fromEntry inventory (lib.parseMelpaRecipe (readFile (path + "/${ename}"))))))
      ]
