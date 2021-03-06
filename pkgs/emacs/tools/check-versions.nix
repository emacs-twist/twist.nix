{
  lib,
  emacsVersion,
  builtinLibraries,
  emptyFile,
  runCommandLocal,
}: packageInputs: let
  inherit
    (builtins)
    mapAttrs
    all
    hasAttr
    elem
    length
    match
    head
    substring
    lessThan
    concatLists
    sort
    concatStringsSep
    attrNames
    ;

  srcDateString = src: substring 0 8 src.lastModifiedDate;

  inputVersion = isDate: attrs:
    if isDate
    then srcDateString attrs.src
    else attrs.version;

  compareVersions = isDate: actual: required:
    if isDate
    then ! lessThan (lib.toInt actual) (lib.toInt required)
    else lib.versionAtLeast actual required;

  # Some packages (e.g. magit) contain dates as dependency versions in *-pkg.el.
  dependencyStatus = ename: required:
    removeAttrs
    rec {
      isDateVersion =
        required
        != null
        && length (lib.splitVersion required) == 1
        && match "[0-9]{8}" (head (lib.splitVersion required)) != null;
      inherit required;
      actual =
        if ename == "emacs"
        then emacsVersion
        else if hasAttr ename packageInputs
        then inputVersion isDateVersion packageInputs.${ename}
        else if elem ename builtinLibraries
        then "builtin"
        else throw "Package ${ename} is missing from packageInputs";
      satisfied =
        required
        == null
        || actual == "builtin"
        || compareVersions isDateVersion actual required;
    } ["isDateVersion"];

  filterErrors = lib.filterAttrs (_: {satisfied, ...}: !satisfied);

  status = rec {
    summary = lib.pipe errors [
      (lib.mapAttrsToList (requiredBy:
        lib.mapAttrsToList
        (ename: status:
          {
            inherit ename requiredBy;
          }
          // status)))
      concatLists
      (lib.groupBy ({ename, ...}: ename))
      (mapAttrs (ename: statuses: {
        current = (head statuses).actual;
        # Showing the source date may be useful, but maybe later.
        #
        # lastModifiedDate =
        #   if hasAttr ename packageInputs
        #   then packageInputs.${ename}.src.lastModifiedDate or null
        #     # unavailable
        #   else null;
        required = lib.pipe (lib.catAttrs "required" statuses) [
          lib.naturalSort
          lib.last
        ];
        details =
          map (status: removeAttrs status ["actual" "ename" "satisfied"]) statuses;
      }))
    ];
    errors = lib.pipe packages [
      (mapAttrs (_: filterErrors))
      (lib.filterAttrs (_: attrs: attrs != {}))
    ];
    packages = lib.pipe packageInputs [
      (mapAttrs (_: {packageRequires, ...}:
          mapAttrs dependencyStatus packageRequires))
    ];
  };
in
  if status.errors == {}
  then emptyFile
  else
    runCommandLocal "emacs-deps-error" {
      passthru = status;
    } ''
      echo >&2 "ERROR: Some packages require updates: ${
        concatStringsSep " " (attrNames status.summary)
      }"
      exit 1
    ''
