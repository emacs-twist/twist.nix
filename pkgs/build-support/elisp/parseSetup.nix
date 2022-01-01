# Parse configuration that uses setup.el <https://git.sr.ht/~pkal/setup>
{ lib
, fromElisp
}:
{ packageKeyword ? ":package"
}:
with builtins;
string:
let
  blocks = fromElisp.fromElisp string;

  go = { elispPackages, rest } @ acc: fields:
    {
      elispPackages = elispPackages ++ lib.pipe fields [
        (map (field:
          if isList field && length field > 0 && head field == packageKeyword
          then elemAt field 1
          else null))
        (filter isString)
      ];
      rest = (lib.pipe fields [
        (filter isList)
        concatLists
        (filter isList)
      ]) ++ rest;
    };

  recurse = { rest, ... } @ acc:
    if rest == [ ]
    then removeAttrs acc [ "rest" ]
    else recurse (go (acc // { rest = [ ]; }) rest);
in
lib.pipe blocks [
  (filter (block: head block == "setup"))
  (map tail)
  (foldl' go {
    elispPackages = [ ];
    rest = [];
  })
  recurse
  (lib.mapAttrs (_: lib.unique))
]
