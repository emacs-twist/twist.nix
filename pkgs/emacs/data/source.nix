{ lib
, lockData
}:
let
  elpaFiles = import ./elpa-files.nix { inherit lib; };
in
with builtins;
self:
{ ename
, type
, entry
}:
{
  pure = hasAttr ename lockData;
  src =
    if self.pure
    then fetchTree lockData.${ename}
    else fetchTree self.origin;
  files =
    if type == "elpa"
    then elpaFiles entry self.src
    else if type == "melpa"
    then lib.expandMelpaRecipeFiles self.src (entry.files or null)
    # Use the default files spec of MELPA.
    # I don't know if this is correct
    else if type == "gitmodules"
    then lib.expandMelpaRecipeFiles self.src null
    else throw "FIXME";
  origin =
    if type == "elpa"
    then lib.flakeRefAttrsFromElpaAttrs { preferReleaseBranch = false; } entry
    else if type == "melpa"
    then lib.flakeRefAttrsFromMelpaRecipe entry
    else if type == "gitmodules"
    then entry
    else throw "Unsupported type: ${type}";
}
