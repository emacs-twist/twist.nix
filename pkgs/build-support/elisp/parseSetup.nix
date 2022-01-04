# Parse configuration that uses setup.el <https://git.sr.ht/~pkal/setup>
{ lib
, fromElisp
}:
{ packageKeyword ? ":package"
}:
with builtins;
string:
let
  setups = lib.pipe (fromElisp.fromElisp string) [
    (filter (block: head block == "setup"))
    (map tail)
  ];

  collect = import ./collectFromSetup.nix { inherit lib; };
in
{
  elispPackages = lib.pipe (collect packageKeyword setups) [
    lib.concatLists
    lib.unique
  ];
}
