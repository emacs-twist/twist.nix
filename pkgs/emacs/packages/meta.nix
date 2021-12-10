{ lib
, headers
}:
let
  inherit (builtins) isString isList;
in
lib.filterAttrs (_: v: v != null) {
  description = headers.summary or null;
  homepage = headers.URL or null;
  license =
    if headers ? SPDX-License-Identifier
    then lib.findLicense headers.SPDX-License-Identifier
    else null;
  maintainers =
    if ! headers ? Maintainer
    then null
    else if isString headers.Maintainer
    then [ headers.Maintainer ]
    else if isList headers.Maintainer
    then headers.Maintainer
    else null;
}
