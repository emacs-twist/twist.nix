# Parse URLs like https://elpa.gnu.org/packages/archive-contents
# and extract URLs
{
  lib,
  archiveLockData,
}:
with builtins;
  {url}: let
    versionString = numbers: concatStringsSep "." (map toString numbers);

    doTangle = false;

    toLockEntry = elpaType: ename: value: rec {
      version = versionString (elemAt value 0);
      packageRequires = lib.pipe (elemAt value 1) [
        (map (ys: {
          name = elemAt ys 0;
          value = versionString (elemAt ys 1);
        }))
        listToAttrs
      ];
      src = fetchTree (builtins.removeAttrs archive ["narHash"]);
      archive =
        {
          type =
            if elpaType == "tar"
            then "tarball"
            else if elpaType == "single"
            then "file"
            else throw "Unsupported type: ${elpaType}";

          url = lib.concatStrings [
            url
            ename
            "-"
            version
            (if elpaType == "tar"
             then ".tar"
             else if elpaType == "single"
             then ".el"
             else throw "Unsupported type: ${elpaType}")
          ];
        }
        // lib.getAttrs [
          "narHash"
        ]
        src;
      inventory = {
        inherit url;
        type = "archive";
      };
      inherit doTangle;
    };

    latest = lib.pipe (lib.readPackageArchiveContents url) [
      (mapAttrs (ename: value:
        toLockEntry (elemAt value 3) ename value))
    ];

    pinned =
      mapAttrs
      (_: locked: {
        src = builtins.fetchTree locked.archive;
        inherit doTangle;
        inherit (locked) version packageRequires archive inventory;
      })
      archiveLockData;
  in
    mode:
      if mode == "update"
      then latest
      else if mode == "lock"
      then pinned // latest
      else
        pinned
        // {
          _impure = latest;
        }
