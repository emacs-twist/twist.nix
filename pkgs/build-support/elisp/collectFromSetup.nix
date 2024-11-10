{lib}: keyword:
with builtins; let
  go = {
    data,
    rest,
  }: fields: {
    data =
      data
      ++ lib.pipe fields [
        (map (field:
          if isList field && length field > 0 && head field == keyword
          then tail field
          else null))
        (filter lib.isList)
      ];
    rest =
      (lib.pipe fields [
        (filter isList)
        concatLists
        (filter isList)
      ])
      ++ rest;
  };

  recurse = {rest, ...} @ acc:
    if rest == []
    then removeAttrs acc ["rest"]
    else recurse (go (acc // {rest = [];}) rest);
in
  blocks:
    lib.pipe blocks [
      (foldl' go {
        data = [];
        rest = [];
      })
      recurse
      (attrs: attrs.data)
    ]
