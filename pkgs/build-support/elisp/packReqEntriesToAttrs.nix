/* Processing a list of Package-Requires in Emacs Lisp libraries.
   <https://www.gnu.org/software/emacs/manual/html_node/elisp/Library-Headers.html>

   This returns a set of attributes in which the name is a library name and
   the value is either a required library version or null.
*/
let
  inherit (builtins) isString isList map head length elemAt listToAttrs;
in
{ lib }:
xs:
lib.pipe xs [
  (map (cellOrString:
    if isString cellOrString
    then {
      name = cellOrString;
      value = null;
    }
    else if isList cellOrString
    then {
      name = lib.removePrefix ":" (head cellOrString);
      # There can be a plist where no value is provided for the final key,
      # which should be considered a nil value.
      #
      # This is valid in lisp, but there is a missing cellOrString, so you have
      # to check it.
      value =
        if (length cellOrString < 2) || (elemAt cellOrString 1) == [ ]
        then null
        else (elemAt cellOrString 1);
    }
    else throw "Unsupported Package-Requires entry: ${cellOrString}"
  ))
  listToAttrs
]
