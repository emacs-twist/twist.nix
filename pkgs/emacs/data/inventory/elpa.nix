{ lib
, flakeLockData
}:
with builtins;
{ path
, ...
} @ args:
let
  elpaEntries = lib.parseElpaPackages (readFile path);

  inventory = args // {
    type = "elpa";
  };

  fileListToAttrs = files: lib.pipe files [
    (map (name: {
      inherit name;
      value = baseNameFromString name;
    }))
    listToAttrs    
  ];

  corePackages =
    if args ? core-src
    then
      lib.pipe elpaEntries [
        (lib.filterAttrs (_: entry: entry ? core))
        (lib.mapAttrs (_: { core, ... } @ entry:
          {
            inherit inventory;
            src = args.core-src;
            doTangle = true;
            files =
              fileListToAttrs
                (if isString core
                 then [ core ]
                 else core);
          }
        ))
      ]
    else { };

  toList = x: if isList x then x else [ x ];

  globToRegex = replaceStrings [ "?" "*" "." ] [ "." ".*" "\\." ];

  filesInDir = src: dir:
    if dir == ""
    then
      lib.pipe (readDir src) [
        attrNames
      ] else
      lib.pipe (readDir (src + "/${dir}")) [
        attrNames
        (map (name: dir + "/" + name))
      ];

  isElisp = lib.hasSuffix ".el";

  baseNameRegexp = ".+/([^/]+)";

  baseNameFromString = pathString:
    if match baseNameRegexp pathString != null
    then head (match baseNameRegexp pathString)
    else pathString;

  makeExternal = ename: entry:
    let
      ignorePatterns = map globToRegex entry.ignored-files;

      p =
        if entry ? ignored-files
        then file: all (pattern: match pattern file == null) ignorePatterns
        else _: true;
    in
    self:
    {
      doTangle = true;
      src =
        if hasAttr ename flakeLockData
        then fetchTree flakeLockData.${ename}
        else fetchTree self.origin;
      origin = lib.flakeRefAttrsFromElpaAttrs { preferReleaseBranch = true; } entry;
      inventory = inventory // { inherit entry; };

      # FIXME: I don't exactly understand how the specs of ELPA work.
      files = lib.pipe
        (
          ((if entry ? lisp-dir
          then filter (file: ! isElisp file)
          else lib.id)
            (filesInDir self.src "")
          )
          ++
          (if entry ? lisp-dir then filter isElisp (filesInDir self.src entry.lisp-dir) else [ ])
          ++
          (if entry ? doc then toList entry.doc else [ ])
          ++
          (if entry ? texinfo then toList entry.texinfo else [ ])
        ) [
        (filter (file: ! (file == ".dir-locals.el" || match "(.+-)?tests?\.el" file != null)))
        (filter p)
        fileListToAttrs
      ];

      preBuild =
        # There are not so many packages that have :make attribute.
        # Only in GNU, and not in non-GNU.
        lib.optionalString (entry ? make) ''
          make ${lib.escapeShellArgs entry.make}
        '';
    }
    //
    lib.optionalAttrs (entry ? renames) {
      renames = lib.pipe entry.renames [
        (map (xs: {
          name = elemAt xs 0;
          value = elemAt xs 1;
        }))
        listToAttrs
      ];
    }
    //
    # Only tramp has this attribute.
    lib.optionalAttrs (entry ? main-file) {
      mainFile = entry.main-file;
    };

  checkUrl = url: url != null && ! lib.hasPrefix "bzr::" url;

  filterAutoSync = (lib.filterAttrs (_: entry: entry ? auto-sync));

  externalPackages = lib.pipe elpaEntries [
    (if args ? auto-sync-only && args.auto-sync-only
    then filterAutoSync
    else lib.id)
    (lib.filterAttrs (_: entry: entry ? url && checkUrl entry.url))
    (lib.mapAttrs makeExternal)
  ];
in
_mode:
corePackages // externalPackages
