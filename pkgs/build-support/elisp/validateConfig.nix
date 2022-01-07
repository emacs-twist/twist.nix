# Validate the output of an init parser
{ lib }:
with builtins;
let
  headOrNull = xs: if length xs == 0 then null else head xs;

  validatePackageList = value:
    if ! isList value
    then "A package list must be a list: ${toJSON value}"
    else lib.pipe value [
      (filter (v: ! isString v))
      (map (v: "Package name must be a string: ${toJSON v}"))
      headOrNull
    ];

  validatePackagePins = value:
    if ! isAttrs value
    then "Package pins must be an attribute set: ${toJSON value}"
    else lib.pipe value [
      (lib.filterAttrs (_name: v: ! isString v))
      (lib.mapAttrsToList (_name: v:
        "A package pin must have a string value: ${toJSON v}"
      ))
      headOrNull
    ];

  checkResultAttr = name: value:
    if name == "elispPackages"
    then validatePackageList value
    else if name == "elispPackagePins"
    then validatePackagePins value
    else if name == "systemPackages"
    then validatePackageList value
    else "Unexpected attribute in the result: ${name}";
in
output:
if ! isAttrs output
then throw "The parser must return attrs"
else if ! output ? elispPackages
then throw "elispPackages is required"
else lib.pipe output [
  (lib.mapAttrsToList checkResultAttr)
  headOrNull
  (r: if r == null then output else throw r)
]
