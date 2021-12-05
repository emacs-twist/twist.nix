{ lib
, headers
}:
let
  inherit (builtins) isString isList;
in
{
  # There are packages that lack a version header, so fallback to zero.
  version = headers.Version or headers.Package-Version or "0.0.0";
  author = headers.Author or null;
  meta = lib.filterAttrs (_: v: v != null) {
    description = headers.description or null;
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
  };
}
