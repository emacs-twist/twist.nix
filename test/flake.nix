{
  description = "";

  nixConfig.extra-substituters = "https://emacs-ci.cachix.org";
  nixConfig.extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";

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

  inputs.emacs-ci = {
    url = "github:purcell/nix-emacs-ci";
    flake = false;
  };

  inputs.home-manager = {
    url = "github:nix-community/home-manager";
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
      inherit (import (inputs.emacs-ci + "/nix/sources.nix") {
        inherit system;
      }) nixpkgs;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import (emacs-ci.outPath + "/overlay.nix"))
          # emacs-unstable.overlay
          inputs.twist.overlays.default
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
            core-src = pkgs.emacs-snapshot.src;
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
        };
      };

      # Another test path to build the whole derivation (not with --dry-run).
      emacs-wrapper = pkgs.emacsTwist {
        emacsPackage = pkgs.emacs-28-2.overrideAttrs (_: {version = "20221201.0";});
        initFiles = [];
        lockDir = ./lock;
        inventories = [];
      };

      # This is an example of interactive Emacs session.
      # You can start Emacs by running `nix run .#emacs-interactive`.
      emacs-interactive = pkgs.writeShellApplication {
        name = "emacs-interactive";

        runtimeInputs = [
          emacs
        ];

        text = ''
          tmpdir=$(mktemp -d twist-test-XXX)
          cleanup() {
            echo "Clean up"
            rm -rf "$tmpdir"
          }
          trap cleanup EXIT ERR
          [[ -f init.el ]] && [[ -f early-init.el ]]
          cp init.el early-init.el "$tmpdir"
          echo "The init directory is $tmpdir"
          emacs --init-directory="$tmpdir" "$@"
        '';
      };

      inherit (flake-utils.lib) mkApp;
    in {
      packages = {
        inherit emacs emacs-wrapper emacs-interactive;
      };
      apps = emacs.makeApps {
        lockDirName = "lock";
      };
      defaultPackage = emacs;
      homeConfigurations = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.twist.homeModules.emacs-twist
          {
            home = {
              stateVersion = "22.11";
              # fake data
              username = "user";
              homeDirectory = "/home/user";
            };
            # Prevent build error
            manual.manpages.enable = false;
            programs.emacs-twist = {
              enable = true;
              name = "my-emacs";
              emacsclient.enable = true;
              directory = ".local/share/emacs";
              earlyInitFile = ./early-init.el;
              config = emacs;
            };
          }
        ];
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
