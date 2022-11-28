{
  lib,
  flakeLockData,
}:
with builtins;
  {path}: mode:
    lib.pipe (lib.readGitModulesFile path) [
      (mapAttrs (ename: origin: self: {
        src =
          if hasAttr ename flakeLockData
          then fetchTree flakeLockData.${ename}
          else
            (
              if mode == "build"
              then trace
              else traceVerbose
            )
            "Impure input for package ${ename} (in gitmodules.nix): ${toJSON self.origin}"
            (fetchTree self.origin);
        doTangle = false;
        files = lib.expandMelpaRecipeFiles self.src null;
        inherit origin;
        inventory = {
          type = "gitmodules";
          inherit path;
        };
      }))
    ]
