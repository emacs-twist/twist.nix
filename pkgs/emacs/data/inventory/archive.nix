{ lib, archiveLockData }:
with builtins;
{ url
}:
let
  versionString = numbers: concatStringsSep "." (map toString numbers);

  doTangle = false;

  tarballEntry = ename: value:
    rec {
      version = versionString (elemAt value 0);
      packageRequires = lib.pipe (elemAt value 1) [
        (map (ys: {
          name = elemAt ys 0;
          value = versionString (elemAt ys 1);
        }))
        listToAttrs
      ];
      src = fetchTree (builtins.removeAttrs archive [ "narHash" ]);
      archive = {
        type = "tarball";
        url = lib.concatStrings [
          url
          ename
          "-"
          version
          ".tar"
        ];
      } // lib.getAttrs [
        "narHash"
      ] src;
      inventory = {
        type = "archive";
        inherit url;
      };
      inherit doTangle;
    };

  latest = lib.pipe (lib.readPackageArchiveContents url) [
    (lib.filterAttrs (_: value: elemAt value 3 == "tar"))
    (mapAttrs tarballEntry)
  ];

  pinned = mapAttrs
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
    //
  {
    _impure = latest;
  }
