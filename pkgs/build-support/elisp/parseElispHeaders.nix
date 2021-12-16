{ lib }: string:
with builtins;
let
  # It should contain at least one line.
  lines = filter isString (split "\n" string);

  # Imports
  trimRight = import ../utils/trimRight.nix;
  trim = import ../utils/trim.nix;
  takeWhile = import ../utils/takeWhile.nix;
  dropWhile = import ../utils/dropWhile.nix;

  # Regular expression patterns
  descriptionRegex = ";;;.+ --- (.+?)";
  magicHeaderRegex = "(.+)-\\*-.+-\\*-[[:space:]]*";
  headerRegex = ";;[[:space:]]*(.*[^[:space:]]):([[:space:]]*.*)?";

  makeHeaderRegex = key: ";;[[:space:]]*${lib.escapeRegex key}[[:space:]]*:([[:space:]]*.*)?";

  headLine = head lines;

  stripMagic = line:
    let
      m = match magicHeaderRegex line;
    in
    if m == null
    then line
    else head m;

  summary =
    let
      m = match descriptionRegex headLine;
    in
    if m == null
    then null
    else trimRight (stripMagic (head m));

  lines' = lib.pipe (if lib.hasInfix "---" headLine then tail lines else lines) [
    (takeWhile (s: match ";;;.*" s == null))
  ];

  isHeader = s: match headerRegex s != null;

  isNotHeader = s: ! (isHeader s);

  findHeader = key: dropWhile (s: match (makeHeaderRegex key) s == null) lines';

  safeHead = xs:
    if length xs == 0
    then null
    else head xs;

  headerContent = key: s: lib.pipe s [
    (match (makeHeaderRegex key))
    (lib.mapNullable (m: trim (head m)))
  ];

  lookupHeader = key: lib.pipe (findHeader key) [
    safeHead
    (lib.mapNullable (headerContent key))
  ];

  uncommentLine = s: lib.pipe (match ";+[[:space:]]*(.+)" s) [
    head
    trim
  ];

  lookupMultiLineHeader = key: pred: lib.pipe (findHeader key) [
    (xs:
      if length xs == 0
      then [ ]
      else [ (headerContent key (head xs)) ]
        ++
        lib.pipe (tail xs)
          [
            (takeWhile pred)
            (map uncommentLine)
          ])
    (filter (s: s != ""))
    (xs:
      if length xs == 0
      then null
      else if length xs == 1
      then head xs
      else xs)
  ];

  succeeding = s: isNotHeader s && s != "";
in
lib.filterAttrs (_: v: v != null) ({
  inherit summary;

  Version = lookupHeader "Version";
  Package-Version = lookupHeader "Package-Version";
  URL = lookupHeader "URL";
  Homepage = lookupHeader "Homepage";
  SPDX-License-Identifier = lookupHeader "SPDX-License-Identifier";
  Keywords = lookupHeader "Keywords";
  Package-Requires = lookupMultiLineHeader "Package-Requires" succeeding;
  Author = lookupMultiLineHeader "Author" succeeding;
  Maintainer = lookupMultiLineHeader "Maintainer" succeeding;

  # Below is optional
  # Created
})
