{ lib
, fromElisp
}:
string:
with builtins;
let
  blocks = fromElisp.fromElisp string;
  plistGet = xs: key:
    if length xs == 0
    then null
    else if head xs == key
    then elemAt xs 1
    else plistGet (tail xs) key;
  isEnsured = form: plistGet form ":ensure" == true;
  isEnabled = form: plistGet form ":disabled" != true;
  ensuredPackageName = form: plistGet form ":ensure";
  findPin = form: plistGet form ":pin";
  isUsePackageForm = xs:
    isList xs
    && length xs > 0
    && head xs == "use-package"
    && isEnabled xs;
  usePackageForms = filter isUsePackageForm blocks;
  enameFromUsePackage = form: elemAt form 1;
  listToSystemPackages = x:
    if isList (head x)
    then map (pname: elemAt pname 1) x
    else tail x;
  toSystemPackages = x:
    if x == null
    then [ ]
    else if isString x
    then [ x ]
    else if isList x
    then listToSystemPackages x
    else trace x (throw ":ensure-system-package must be either a list or a string");
  ensuredSystemPackages = form:
    toSystemPackages (plistGet form ":ensure-system-package");
  directPackages = map enameFromUsePackage (filter isEnsured usePackageForms);
  indirectPackages = filter isString (map ensuredPackageName usePackageForms);
in
{
  elispPackages = lib.unique (directPackages ++ indirectPackages);
  elispPackagePins = lib.pipe usePackageForms [
    (map (form: {
      # Don't consider :ensure keyword for now.
      name = enameFromUsePackage form;
      value = findPin form;
    }))
    (filter ({ value, ... }: value != null))
    listToAttrs
  ];
  systemPackages = lib.concatMap ensuredSystemPackages usePackageForms;
}
