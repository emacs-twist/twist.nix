{ lib
, flakeLockData
}:
with builtins;
{ path
}:
_mode:
lib.pipe (lib.readGitModulesFile path) [
  (mapAttrs (ename: origin: self: {
    src =
      if hasAttr ename flakeLockData
      then fetchTree flakeLockData.${ename}
      else fetchTree self.origin;
    customUnpackPhase = false;
    files = lib.expandMelpaRecipeFiles self.src null;
    inherit origin;
    inventory = {
      type = "gitmodules";
      inherit path;
    };
  }))
]
