{
  lib
, lockFile
, elispPackages
}:
let
  inherit (builtins) intersectAttrs mapAttrs hasAttr throw;

  prev = lib.importJSON lockFile;

  newNodeAttrs = ename: value:
    let
      package = elispPackages.${ename};
      original = package.passthru.elispAttrs.origin;
    in
    {
      inherit original;
      locked = original // intersectAttrs value.locked package.src;
    };

  version7 =
    prev
    //
    {
      nodes = mapAttrs (ename: value:
        if hasAttr ename elispPackages
        then value // newNodeAttrs ename value
        else value)
        prev.nodes;
    };
in
if prev.version == 7
then version7
else throw "Unsupported flake.lock version ${prev.version}"
