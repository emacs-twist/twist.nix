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
