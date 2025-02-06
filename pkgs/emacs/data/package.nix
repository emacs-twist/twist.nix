let
  inherit
    (builtins)
    pathExists
    hasAttr
    readFile
    attrNames
    filter
    match
    length
    head
    toJSON
    isAttrs
    isFunction
    ;
in
  {
    lib,
    linkFarm,
    defaultMainIsAscii,
    cachedMetadata,
  }: ename: mkAttrs: self: let
    attrs =
      if isAttrs mkAttrs
      then mkAttrs
      else if isFunction mkAttrs
      then mkAttrs self
      else throw "Unsupported type: ${toJSON mkAttrs}";
    pkgFiles = lib.pipe self.files [
      attrNames
      (filter (filename: baseNameOf filename == ename + "-pkg.el"))
    ];
    pkgFile =
      if length pkgFiles != 0
      then self.src + "/${head pkgFiles}"
      else self.src + "/${ename}-pkg.el";
    #  OPTIMIZE: Reduce filesystem access
    hasPkgFile =
      length pkgFiles
      != 0
      || pathExists pkgFile;
    packageDesc =
      # If the package description does not specify dependencies,
      # packageRequires attribute will be null, so remove the attribute.
      if hasPkgFile
      then
        lib.warnIf (self ? ignorePkgFile) "ignorePkgFile is obsolete and does not take effect."
        (
          lib.filterAttrs (_: v: v != null)
          (lib.parsePkg (readFile pkgFile))
        )
      else {};

    metadata =
      if hasAttr ename cachedMetadata && cachedMetadata.${ename}.narHash == (self.src.narHash or null)
      then cachedMetadata.${ename}
      else {};

    # builtins.readFile fails when the source file contains control characters.
    # pydoc.el is an example. A workaround is to take only the first N bytes of
    # the file using `head` command and read its output. This is IFD, which
    # effectively prevents you from adding elisp packages directly to the flake
    # outputs.
    headers =
      lib.parseElispHeaders
      (
        # Add support for an option to remove IFD.
        if self.mainIsAscii or defaultMainIsAscii
        then builtins.readFile (self.src + "/${self.mainFile}")
        else
          (lib.readFirstBytes
            # magit.el has a relatively long header, so other libraries would be shorter.
            1500
            (self.src + "/${self.mainFile}"))
      );
  in
    lib.getAttrs
    (filter (name: hasAttr name attrs) [
      "entry"
      "renames"
      "origin"
      "archive"
      "preBuild"
    ])
    attrs
    // {
      inherit ename;
      inherit (attrs) inventory doTangle;
      src =
        # If the source if a single-file archive from ELPA or MELPA, src will be
        # a file, and not a directory, so the file should be put in a directory.
        if attrs.inventory.type == "archive" && attrs.archive.type == "file"
        then
          linkFarm (ename + ".el") [
            {
              name = ename + ".el";
              path = attrs.src;
            }
          ]
        else attrs.src;

      files = attrs.files or (lib.expandMelpaRecipeFiles self.src null);

      lispFiles = lib.pipe self.files [
        # Some packages contain contributing files in a subdirectory. See slime,
        # ESS, etc. They are usually not supposed to be byte-compiled.
        (lib.filterAttrs (_: file: match "[^/]+\\.el" file != null))
        attrNames
        # *-pkg.el is not required unless you use package.el, and it makes
        # *-byte-compile fail, so exclude them.
        (filter (filename: !(lib.hasSuffix "-pkg.el" filename)))
      ];

      mainFile =
        attrs.mainFile or (lib.findFirst
          (file: baseNameOf file == ename + ".el")
          (
            if length self.lispFiles > 0
            then head self.lispFiles
            else
              throw ''
                Package ${ename} contains no *.el file.
                Check the contents in the store: ${self.src}
                Files: ${toJSON self.lispFiles}
                Entry: ${toJSON attrs.inventory}
              ''
          )
          self.lispFiles);

      # TODO: Check https://github.com/melpa/melpa/issues/2955 on the right versioning scheme
      version =
        metadata.version
        or attrs.version
        or headers.Version
        or headers.Package-Version
        or packageDesc.version
        # Set a null version if the package lacks a version header.
        or null;

      author =
        metadata.author
        or headers.Author or null;

      meta =
        metadata.meta
        or ((lib.optionalAttrs hasPkgFile {
            description = packageDesc.summary;
          })
          // (import ./headers-to-meta.nix {
            inherit lib headers;
          }));

      packageRequires =
        metadata.packageRequires
        or attrs.packageRequires
        or packageDesc.packageRequires
        or (
          if headers ? Package-Requires
          then lib.parsePackageRequireLines headers.Package-Requires
          else {}
        );
    }
