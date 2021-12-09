# This function was intended for use inside overrideScope' call but is
# currently deprecated. This function would slightly reduce a boilerplate,
# but I am not sure if it is useful.
{ lib }:
super: path:
let
  inherit (builtins) length elemAt;
  n = length path;
  parent = lib.attrByPath (lib.take (n - 1) path) null super;
  prev = lib.attrByPath path null super;
in
f:
lib.setAttrByPath (lib.take (n - 1) path) (
  parent
  //
  {
    ${elemAt path (n - 1)} = prev.overrideAttrs f;
  }
)
