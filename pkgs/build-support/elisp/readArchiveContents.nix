{ lib
, fromElisp
}:
prefixUrl:
with builtins;
lib.pipe (fetchurl (prefixUrl + "archive-contents")) [
  readFile
  fromElisp.fromElisp
  head
  # I don't understand the exact format of the package archives.
  # I don't know why the first element is 1, but I'll just drop it.
  tail
  (map (xs: {
    name = head xs;
    value = tail xs;
  }))
  listToAttrs
]
