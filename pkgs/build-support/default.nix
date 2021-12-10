{ lib
, inputs
}:
let
  inherit (builtins) head attrValues replaceStrings isList;

  fromElisp = import inputs.fromElisp {
    pkgs = { inherit lib; };
  };

  elispHelpers = import inputs.elisp-helpers {
    pkgs = { inherit lib; };
  };

  packReqEntriesToAttrs = import ./elisp/packReqEntriesToAttrs.nix { inherit lib; };
in
lib
  //
{
  inherit (inputs.gitignore.lib) gitignoreSource;

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
    lib.pipe (if isList lines then lib.concatStringsSep " " lines else lines) [
      fromElisp.fromElisp
      head
      packReqEntriesToAttrs
    ];

  parseUsePackages = import ./elisp/parseUsePackages.nix { inherit lib fromElisp; };

  # Just a shorthand for overriding a nested attribute.
  # I am looking for a better syntax for overriding multiple packages.
  # I would want a kind of recursive updating with recursion limit.
  # overrideAttrsByPath = import ./overrideAttrsByPath.nix { inherit lib; };
}
