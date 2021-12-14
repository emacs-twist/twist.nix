{
  description = "";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.twist = {
    url = "github:akirak/emacs-twist";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  inputs.melpa = {
    url = "github:melpa/melpa";
    flake = false;
  };
  inputs.gnu-elpa = {
    url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
    flake = false;
  };
  inputs.nongnu-elpa = {
    url = "git+https://git.savannah.gnu.org/git/emacs/nongnu.git?ref=main";
    flake = false;
  };

  inputs.emacs-unstable = {
    url = "github:nix-community/emacs-overlay";
  };

  outputs =
    { flake-utils
    , nixpkgs
    , emacs-unstable
    , ...
    } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (builtins) filter match elem;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          emacs-unstable.overlay
          inputs.twist.overlay
        ];
      };

      inherit (pkgs) lib;

      emacs = (pkgs.emacsTwist {
        emacs = pkgs.emacsPgtkGcc.overrideAttrs (_: { version = "29.0.50"; });
        initFiles = [
          ./init.el
        ];
        lockFile = ./repos/flake.lock;
        inventorySpecs = [
          {
            type = "elpa";
            path = inputs.gnu-elpa.outPath + "/elpa-packages";
          }
          {
            type = "elpa";
            path = inputs.nongnu-elpa.outPath + "/elpa-packages";
          }
          {
            type = "melpa";
            path = inputs.melpa.outPath + "/recipes";
          }
        ];
        inputOverrides = {
          ivy = _: ivy: {
            # You can filter package files.
            files = lib.pipe ivy.files [
              (filter (name: match "ivy.+" name != null || name == "colir.el"))
              (filter (name: ! elem name [
                "ivy-test.el"
                "ivy-avy.el"
                "ivy-hydra.el"
              ]))
            ];
          };
        };
      });

      inherit (flake-utils.lib) mkApp;
    in
    {
      packages = {
        inherit emacs;
      };

      apps.lock = flake-utils.lib.mkApp {
        drv = pkgs.writeShellApplication {
          name = "lock";
          runtimeInputs = [
            pkgs.nixfmt
          ];
          text = ''
            if [[ ! -f repos/flake.nix ]]
            then
              touch repos/flake.nix
              git add repos/flake.nix
            fi

            nix eval --impure .#packages.${system}.emacs.flakeNix \
              | nixfmt \
              | sed -e 's/<LAMBDA>/{ ... }: { }/' \
              > repos/flake.nix
            cd repos
            nix flake lock
          '';
        };
      };

      apps.sync = flake-utils.lib.mkApp {
        drv = pkgs.writeShellApplication {
          name = "sync";
          runtimeInputs = [
            pkgs.jq
          ];
          text = ''
            tmp=$(mktemp -t emacs-XXX.lock)
            cleanup() {
              rm -f "$tmp"
            }
            trap cleanup EXIT ERR
            nix eval --json --impure .#packages.${system}.emacs.flakeLock \
              | jq \
              > "$tmp"
            cp "$tmp" repos/flake.lock
          '';
        };
      };
    });
}
