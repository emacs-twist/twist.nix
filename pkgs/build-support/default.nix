{ pkgs
, inputs
}:
let
  inherit (builtins) head attrNames attrValues filter replaceStrings isList length
    listToAttrs split match elemAt isString readFile;

  inherit (pkgs) lib;

  fromElisp = import inputs.fromElisp {
    pkgs = { inherit lib; };
  };

  elispHelpers = import inputs.elisp-helpers {
    pkgs = { inherit lib; };
  };

  packReqEntriesToAttrs = import ./elisp/packReqEntriesToAttrs.nix { inherit lib; };

  gitUrlToAttrs = import ./gitUrlToAttrs.nix;

  parseSubmoduleConfigEntries = s: lib.pipe s [
    (split "\n")
    (filter isString)
    # Exclude entries starting with _
    (map (match "submodule.([^_][^.]+).url=(.+)"))
    (filter isList)
    (map (x: ({
      name = elemAt x 0;
      value = gitUrlToAttrs (elemAt x 1);
    })))
    listToAttrs
  ];
in
lib
  //
{
  inherit (elispHelpers)
    parsePkg
    parseElpaPackages
    flakeRefAttrsFromElpaAttrs
    parseMelpaRecipe
    flakeRefAttrsFromMelpaRecipe
    expandMelpaRecipeFiles;

  makeSourceVersion = version: _src: version;
  toPName = replaceStrings [ "@" ] [ "at" ];

  findLicense = spdxId:
    lib.findFirst
      (license: (license ? spdxId && license.spdxId == spdxId))
      null
      (attrValues lib.licenses);

  parseElispHeaders = import ./elisp/parseElispHeaders.nix { inherit lib; };

  parsePackageRequireLines = lines:
    if lines == null
    then { }
    else
      lib.pipe (if isList lines then lib.concatStringsSep " " lines else lines) [
        fromElisp.fromElisp
        (xs: if length xs == 0 then [ ] else head xs)
        packReqEntriesToAttrs
      ];

  parseUsePackages = import ./elisp/parseUsePackages.nix { inherit lib fromElisp; };

  /* Transform an attribute set of packageRequires to a list of library names,
    excluding emacs. */
  packageRequiresToLibraryNames = packageRequires: lib.pipe packageRequires [
    attrNames
    (filter (name: name != "emacs"))
  ];

  readGitModulesFile = file: parseSubmoduleConfigEntries
    (readFile (pkgs.callPackage
      ({ git, runCommandLocal }:
        runCommandLocal "gitmodules-output" { } ''
          ${git}/bin/git --no-pager config --list -f ${file} > $out
        '')
      { }));

  readFirstBytes = limit: file:
    readFile (pkgs.callPackage
      ({ runCommandLocal }:
        runCommandLocal "main-file" { } ''
          head -c ${toString limit} ${file} > $out
        '')
      { });

  # Just a shorthand for overriding a nested attribute.
  # I am looking for a better syntax for overriding multiple packages.
  # I would want a kind of recursive updating with recursion limit.
  # overrideAttrsByPath = import ./overrideAttrsByPath.nix { inherit lib; };

  readPackageArchiveContents = import ./elisp/readArchiveContents.nix {
    inherit lib fromElisp;
  };
}
