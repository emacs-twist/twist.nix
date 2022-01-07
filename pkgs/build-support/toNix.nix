/* An incomplete implementation of Nix serialization. */
{ lib }:
let
  inherit (builtins) isList isAttrs isFunction toJSON concatStringsSep;

  isPrimitive = v: ! (isList v || isAttrs v || isFunction v);

  wrap = open: close: body: open + body + close;

  printList = v:
    wrap "[ " " ]"
      (lib.concatMapStringsSep " " go v);

  printAttr = name: value:
    (if lib ? escapeNixIdentifier then lib.escapeNixIdentifier name else name)
    + " = " + go value + ";";

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
