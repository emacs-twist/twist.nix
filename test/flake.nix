{
  nixConfig = {
    extra-substituters = "https://emacs-ci.cachix.org";
    extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

    emacs-ci.url = "github:purcell/nix-emacs-ci";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    emacs-ci,
    self,
    ...
  } @ inputs: let
    inherit (builtins) listToAttrs map filter match elem;

    makeHomeConfiguration = system:
      import ./home.nix rec {
        inherit inputs;
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (nixpkgs) lib;
        inherit (self.packages.${system}) emacs;
      };
  in
    {
      homeConfigurations = listToAttrs (map (system: {
          name = system;
          value = makeHomeConfiguration system;
        }) [
          "x86_64-linux"
          "aarch64-darwin"
        ]);
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          # emacs-unstable.overlay
          inputs.twist.overlays.default
        ];
      };

      inherit (pkgs) lib;

      emacsPackage = emacs-ci.packages.${system}.emacs-snapshot;

      emacs = pkgs.callPackage ./twist.nix {
        inherit inputs;
        inherit emacsPackage;
      };

      # Another test path to build the whole derivation (not with --dry-run).
      emacs-wrapper = pkgs.callPackage ./twist-minimal.nix {
        inherit emacsPackage;
      };

      # This is an example of interactive Emacs session.
      # You can start Emacs by running `nix run .#emacs-interactive`.
      emacs-interactive = pkgs.callPackage ./interactive.nix {inherit emacs;};

      inherit (flake-utils.lib) mkApp;
    in {
      packages = {
        inherit emacs emacs-wrapper emacs-interactive;
      };
      apps = emacs.makeApps {
        lockDirName = "lock";
      };
      defaultPackage = emacs;
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
