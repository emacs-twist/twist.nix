{
  description = "Generate alternative documentation formats from Org";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.emacs-ci = {
    url = "github:purcell/nix-emacs-ci";
    flake = false;
  };

  outputs = {
    nixpkgs,
    flake-utils,
    emacs-ci,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import (emacs-ci.outPath + "/overlay.nix"))
          ];
        };
      in rec {
        # Run this app at the repository root to update documentation in the
        # doc directory.
        apps.generate-info = flake-utils.lib.mkApp {
          drv = pkgs.writeShellApplication {
            name = "generate-info";
            runtimeInputs = with pkgs; [
              emacs-snapshot
              texinfo
            ];
            text = ''
              basename=emacs-twist
              emacs -Q --batch -l ox-texinfo \
                --eval "(progn
                          (find-file \"$basename.org\")
                          (org-texinfo-export-to-texinfo))"

              shopt -s nullglob
              for t in *.texi *.texinfo
              do
                makeinfo --no-split "$t" -o "''${t%%.*}.info"
              done
            '';
          };
        };
        defaultApp = apps.generate-info;
      }
    );
}
