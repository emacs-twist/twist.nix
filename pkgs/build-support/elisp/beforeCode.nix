{ runCommandLocal
}:
file:
let
  inherit (builtins) baseNameOf readFile;
  drv = runCommandLocal (baseNameOf file) { } ''
    set -euo pipefail
    src="${file}"
    pos=$(grep -E '^;+\s+Code:' --binary-files=text -b "$src" | cut -d: -f1)
    head -c "$pos" "$src" > $out
  '';
in
# This is an IFD.
readFile drv
