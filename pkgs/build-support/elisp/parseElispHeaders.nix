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
  headerRegex = ";;[[:space:]]*([-[:alpha:]]+):([[:space:]]+.+)?";

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

  p1 = s: match ";;.+" s != null && !(isHeader s);

  go' = acc: first: extra: input:
    go
      (acc // {
        ${elemAt first 0} =
          if length extra == 0
          then trim (elemAt first 1)
          else if elemAt first 1 == null
          then extra
          else [ (trim (elemAt first 1)) ] ++ extra;
      })
      (lib.drop (1 + length extra) input);

  go = acc: rest:
    if length rest == 0
    then acc
    else if isHeader (head rest)
    then
      go' acc (match headerRegex (head rest))
        (lib.pipe (tail rest) [
          (takeWhile p1)
          (map (s: substring 2 (lib.stringLength s - 2) s))
          (map trim)
        ])
        rest
    else go acc (dropWhile isNotHeader rest);

  headers = go { } lines';
in
(lib.optionalAttrs (summary != null) { inherit summary; })
  //
headers
