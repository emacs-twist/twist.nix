{
  lib,
  flakeLockData,
}:
with builtins;
{ path, base-url }:
mode:
let
  versionString = numbers: concatStringsSep "." (map toString numbers);

  doTangle = false;

  fromEntry =
    elpaType: ename: value:
    let
      locked = flakeLockData.${ename};

      impure = {
        type =
          if elpaType == "tar" then
            "tarball"
          else if elpaType == "single" then
            "file"
          else
            throw "Unsupported type: ${elpaType}";

        url = lib.concatStrings [
          base-url
          ename
          "-"
          (versionString (elemAt value 0))
          (
            if elpaType == "tar" then
              ".tar"
            else if elpaType == "single" then
              ".el"
            else
              throw "Unsupported type: ${elpaType}"
          )
        ];
      };

      origin =
        if mode == "update" then
          impure
        else if hasAttr ename flakeLockData then
          locked
        else
          impure;
    in
    {
      src =
        if hasAttr "narHash" origin then
          fetchTree origin
        else
          (if mode == "build" then trace else traceVerbose)
            "Impure input for package ${ename} (in archive-contents.nix): ${toJSON impure}"
            fetchTree
            origin;

      origin = lib.filterAttrs (name: _: name != "narHash") origin;

      inventory = {
        inherit path base-url;
        type = "archive-contents";
      };

      inherit doTangle;
    };
in
lib.pipe (lib.readPackageArchiveContentsPath path) [
  (mapAttrs (ename: value: fromEntry (elemAt value 3) ename value))
]
