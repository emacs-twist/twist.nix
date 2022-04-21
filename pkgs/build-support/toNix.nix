/*
 An incomplete implementation of Nix serialization.
 */
{lib}: let
  inherit (builtins) isList isAttrs isFunction toJSON concatStringsSep match;

  isPrimitive = v: ! (isList v || isAttrs v || isFunction v);

  wrap = open: close: body: open + body + close;

  printList = v:
    wrap "[ " " ]"
    (lib.concatMapStringsSep " " go v);

  escapeAttrName = str:
    if match "[a-zA-Z_][-a-zA-Z0-9_']+" str != null
    then str
    else "\"${str}\"";

  printAttr = name: value: escapeAttrName name + " = " + go value + ";";

  printAttrs = v:
    wrap "{ " " }"
    (concatStringsSep " " (lib.mapAttrsToList printAttr v));

  go = v:
    if isList v
    then printList v
    else if isAttrs v
    then printAttrs v
    else if isFunction v
    then "<LAMBDA>"
    else toJSON v;
in
  go
