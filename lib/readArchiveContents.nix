{ lib
, fromElisp
}:
prefixUrl:
with builtins;
let
  tarballEntry = xs:
    # Process only tarball
    if elemAt xs 4 == "tar"
    then {
      name = head xs;
      value = {
        type = "tarball";
        url = lib.concatStrings [
          prefixUrl
          (head xs)
          "-"
          (concatStringsSep "." (map toString (elemAt xs 1)))
          ".tar"
        ];
      };
    }
    else null;
in
lib.pipe (fetchurl (prefixUrl + "archive-contents")) [
  readFile
  fromElisp.fromElisp
  head
  # I don't understand the exact format of the package archives.
  # I don't know why the first element is 1, but I'll just drop it.
  tail
  (map tarballEntry)
  (filter (x: x != null))
  listToAttrs
  (lib.setAttrByPath ["tarballs"])
]
