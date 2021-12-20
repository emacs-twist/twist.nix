{ lib
, flakeLock
, packageInputs
}:
let
  inherit (builtins) intersectAttrs mapAttrs hasAttr throw;

  # It would be possible to generate an entirely new lock file, but I prefer not
  # duplicating the boilerplate into my code.
  prev = lib.importJSON flakeLock;

  newNodeAttrs = attrs: value:
    if attrs ? origin && attrs.origin != null
    then
      rec {
        original = attrs.origin;
        locked = original // intersectAttrs value.locked attrs.src;
      }
    else null;

  version7 =
    prev
    //
    {
      nodes = lib.pipe prev.nodes [
        (mapAttrs
          (ename: value:
            if hasAttr ename packageInputs
            then value // newNodeAttrs packageInputs.${ename} value
            else value))
      ];
    };
in
if prev.version == 7
then version7
else throw "Unsupported flake.lock version ${prev.version}"
