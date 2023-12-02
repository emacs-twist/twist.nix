{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    twist.url = "github:emacs-twist/twist.nix";
    # org-babel.url = "github:emacs-twist/org-babel";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixpkgs-emacs.url = "github:NixOS/nixpkgs";

    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };
    gnu-elpa = {
      url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
      flake = false;
    };
    nongnu = {
      url = "git+https://git.savannah.gnu.org/git/emacs/nongnu.git?ref=main";
      flake = false;
    };
    epkgs = {
      url = "github:emacsmirror/epkgs";
      flake = false;
    };
    emacs = {
      url = "github:emacs-mirror/emacs";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-emacs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            inputs.twist.overlay
          ];
        };

        # Allow updating nixpkgs without rebuilding the Emacs binary.
        pkgsForEmacs = import nixpkgs-emacs {
          inherit system;
          overlays = [
            inputs.emacs-overlay.overlay
          ];
        };

        emacs = pkgs.emacsTwist {
          emacsPackage = pkgsForEmacs.emacsUnstable.overrideAttrs (_: {
            version = "28.0.91";
          });

          registries = import ./registries.nix inputs;
          lockDir = ./lock;
          initFiles = [
            ./init.el
          ];
          # inputOverrides = { };
        };
      in rec {
        packages = flake-utils.lib.flattenTree {
          inherit emacs;
        };
        apps = emacs.makeApps {
          lockDirName = "lock";
        };
        defaultPackage = packages.emacs;
      }
    );
}
