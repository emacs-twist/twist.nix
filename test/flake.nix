{
  nixConfig = {
    extra-substituters = "https://emacs-ci.cachix.org";
    extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
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

    emacs-ci.url = "github:purcell/nix-emacs-ci";
    emacs-builtins.url = "github:emacs-twist/emacs-builtins";
  };

  outputs =
    {
      nixpkgs,
      systems,
      emacs-ci,
      self,
      ...
    }@inputs:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);

      eachSystemPkgs =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [
                inputs.twist.overlays.default
                (final: prev: {
                  emacsPackage = emacs-ci.packages.${system}.emacs-snapshot;
                })
              ];
            }
          )
        );
    in
    {
      devShells = eachSystemPkgs (pkgs: {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.just
          ];
        };
      });

      packages = eachSystemPkgs (pkgs: {
        emacs = pkgs.callPackage ./twist.nix {
          inherit inputs;
          inherit (pkgs) emacsPackage;
        };

        # With explicit buitlins
        emacs-builtins = pkgs.callPackage ./twist.nix {
          inherit inputs;
          inherit (pkgs) emacsPackage;
          initialLibraries = inputs.emacs-builtins.data.emacs-snapshot.libraries;
        };

        # Another test path to build the whole derivation (not with --dry-run).
        emacs-wrapper = pkgs.callPackage ./twist-minimal.nix {
          inherit (pkgs) emacsPackage;
        };

        # This is an example of interactive Emacs session.
        # You can start Emacs by running `nix run .#emacs-interactive`.
        emacs-interactive = pkgs.callPackage ./interactive.nix {
          inherit (self.packages.${pkgs.system}) emacs;
        };

        # An example of ELPA-compatible package archive
        elpa-archive =
          inputs.twist.lib.buildElpaArchive pkgs
            self.packages.${pkgs.system}.emacs.packageInputs.dash;
      });

      homeConfigurations = eachSystem (
        system:
        import ./home.nix rec {
          inherit inputs;
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (nixpkgs) lib;
          inherit (self.packages.${system}) emacs;
        }
      );

      apps = eachSystem (
        system:
        self.packages.${system}.emacs.makeApps {
          lockDirName = "lock";
        }
      );

      checks = eachSystemPkgs (pkgs: {
        symlink = pkgs.stdenv.mkDerivation {
          name = "emacs-twist-wrapper-test";
          src = self.packages.${pkgs.system}.emacs-wrapper;
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
      });
    };
}
