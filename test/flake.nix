{
  nixConfig = {
    extra-substituters = "https://emacs-ci.cachix.org";
    extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";
  };

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    twist.url = "github:emacs-twist/twist.nix";
    home-manager.url = "github:nix-community/home-manager";

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

    emacs-ci = {
      url = "github:purcell/nix-emacs-ci";
      flake = false;
    };
  };

  outputs = {
    flake-utils,
    emacs-ci,
    # , emacs-unstable
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      inherit (builtins) filter match elem;

      # Access niv sources of nix-emacs-ci
      inherit
        (import (inputs.emacs-ci + "/nix/sources.nix") {
          inherit system;
        })
        nixpkgs
        ;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import (emacs-ci.outPath + "/overlay.nix"))
          # emacs-unstable.overlay
          inputs.twist.overlays.default
        ];
      };

      inherit (pkgs) lib;

      emacs = pkgs.callPackage ./twist.nix { inherit inputs; };

      # Another test path to build the whole derivation (not with --dry-run).
      emacs-wrapper = pkgs.callPackage ./twist-minimal.nix { };

      # This is an example of interactive Emacs session.
      # You can start Emacs by running `nix run .#emacs-interactive`.
      emacs-interactive = pkgs.callPackage ./interactive.nix { inherit emacs; };

      inherit (flake-utils.lib) mkApp;
    in {
      packages = {
        inherit emacs emacs-wrapper emacs-interactive;
      };
      apps = emacs.makeApps {
        lockDirName = "lock";
      };
      defaultPackage = emacs;
      homeConfigurations = import ./home.nix {
        inherit inputs emacs pkgs;
      };
      checks = {
        symlink = pkgs.stdenv.mkDerivation {
          name = "emacs-twist-wrapper-test";
          src = emacs-wrapper;
          doCheck = true;
          checkPhase = ''
            cd $src
            tmp=$(mktemp)
            echo "Checking missing symlinks"
            find -L -type l | tee $tmp
            [[ ! -s $tmp ]]
            success=1
          '';
          installPhase = ''
            [[ $success -eq 1 ]]
            touch $out
          '';
        };
      };
    });
}
