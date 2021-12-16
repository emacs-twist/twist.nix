{ lib }:
with builtins;
attrs: src:
let
  lispDir =
    if attrs ? lisp-dir
    then src + "/${attrs.lisp-dir}"
    else src;

  globToRegex = replaceStrings [ "?" "*" "." ] [ "." ".*" "\\." ];

  ignorePatterns = map globToRegex (attrs.ignored-files or [ ]);

  # TODO: Scan the directory recursively.
  #
  # This isn't fatal, as we are mostly interested in lisp files, which is
  # specified in optional :lisp-dir field.
  elpaLispFiles =
    lib.pipe lispDir [
      readDir
      (lib.filterAttrs (_: type: type == "regular"))
      attrNames
      # FIXME: If :lisp-dir is specified, other files (e.g. doc) are ignored
      (map (file:
        if attrs ? lisp-dir
        then "${attrs.lisp-dir}/${file}"
        else file))
      (filter (file: all (pattern: match pattern file == null) ignorePatterns))
    ];

  elpaDocFiles =
    if ! attrs ? doc
    then [ ]
    else if isString attrs.doc
    then [ attrs.doc ]
    else if isList attrs.doc
    then attrs.doc
    else throw "The value of :doc must be either a string or alist: ${attrs.doc}";
in
lib.unique (elpaLispFiles ++ elpaDocFiles)

