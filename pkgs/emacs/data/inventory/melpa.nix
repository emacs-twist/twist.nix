{ lib
, flakeLockData
}:
with builtins;
let
  fromEntry = { ename, ... } @ entry: self:
    {
      src =
        if hasAttr ename flakeLockData
        then fetchTree flakeLockData.${ename}
        else fetchTree self.origin;
      customUnpackPhase = true;
      files = lib.expandMelpaRecipeFiles self.src (entry.files or null);
      origin = lib.flakeRefAttrsFromMelpaRecipe entry;
      inherit entry;
    };
in
{ path
}:
_mode:
lib.pipe (readDir path) [
  (lib.filterAttrs (_: type: type == "regular"))
  (mapAttrs (ename: _:
    fromEntry (lib.parseMelpaRecipe (readFile (path + "/${ename}"))))
  )
]
