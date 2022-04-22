{
  description = "";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.twist = {
    url = "github:emacs-twist/twist.nix";
  };

  inputs.melpa = {
    url = "github:melpa/melpa";
    flake = false;
  };
  inputs.gnu-elpa = {
    url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
    flake = false;
  };
  inputs.nongnu = {
    url = "git+https://git.savannah.gnu.org/git/emacs/nongnu.git?ref=main";
    flake = false;
  };
  inputs.epkgs = {
    url = "github:emacsmirror/epkgs";
    flake = false;
  };

  inputs.emacs = {
    url = "github:emacs-mirror/emacs";
    flake = false;
  };

  inputs.emacs-ci = {
    url = "github:purcell/nix-emacs-ci";
    flake = false;
  };

  # You could use one of the Emacs builds from emacs-overlay,
  # but I wouldn't use it on CI.
  #
  # inputs.emacs-unstable = {
  #   url = "github:nix-community/emacs-overlay";
  # };

  outputs = {
    flake-utils,
    emacs-ci,
    # , emacs-unstable
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      inherit (builtins) filter match elem;

      # Access niv sources of nix-emacs-ci
      inherit (import (inputs.emacs-ci + "/nix/sources.nix")) nixpkgs;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import (emacs-ci.outPath + "/overlay.nix"))
          # emacs-unstable.overlay
          inputs.twist.overlay
        ];
      };

      inherit (pkgs) lib;

      emacs = pkgs.emacsTwist {
        # Use nix-emacs-ci which is more lightweight than a regular build
        emacsPackage = pkgs.emacs-snapshot;
        # In an actual configuration, you would use this:
        # emacs = pkgs.emacsPgtkGcc.overrideAttrs (_: { version = "29.0.50"; });
        initFiles = [
          ./init.el
        ];
        lockDir = ./lock;
        inventories = [
          {
            type = "elpa";
            path = inputs.gnu-elpa.outPath + "/elpa-packages";
            core-src = inputs.emacs.outPath;
            auto-sync-only = true;
          }
          {
            name = "melpa";
            type = "melpa";
            path = inputs.melpa.outPath + "/recipes";
          }
          {
            type = "elpa";
            path = inputs.nongnu.outPath + "/elpa-packages";
          }
          {
            name = "gnu";
            type = "archive";
            url = "https://elpa.gnu.org/packages/";
          }
          {
            name = "emacsmirror";
            type = "gitmodules";
            path = inputs.epkgs.outPath + "/.gitmodules";
          }
        ];
        inputOverrides = {
          bbdb = _: super: {
            files = builtins.removeAttrs super.files [
              "bbdb-vm.el"
              "bbdb-vm-aux.el"
            ];
          };
          # google-translate currently contains an invalid pkg file, but it may
          # be fixed later. See
          # https://github.com/atykhonov/google-translate/pull/148
          google-translate = _: _: {
            ignorePkgFile = true;
          };
          # This package contains a pkg file without the dependencies field
          drag-stuff = _: _: {
            ignorePkgFile = true;
          };
        };
      };

      inherit (flake-utils.lib) mkApp;
    in {
      packages = {
        inherit emacs;
      };
      apps = emacs.makeApps {
        lockDirName = "lock";
      };
      defaultPackage = emacs;
    });
}
