{
  description = "Source-based Emacs Lisp build machinery";

  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };
  inputs.elisp-helpers = {
    url = "github:akirak/nix-elisp-helpers";
    flake = false;
  };
  inputs.fromElisp = {
    url = "github:talyz/fromElisp";
    flake = false;
  };
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , pre-commit-hooks
    , ...
    } @ inputs:
    ({
      overlay = _self: import ./pkgs inputs;
    }
    //
    (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # Run this app at the repository root to update documentation in the
      # doc directory.
      apps.generate-info = flake-utils.lib.mkApp {
        drv = pkgs.writeShellApplication {
          name = "generate-info";
          runtimeInputs = with pkgs; [ emacs texinfo ];
          text = ''
            cd doc
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
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            nix-linter.enable = true;
          };
        };
      };
      devShell = nixpkgs.legacyPackages.${system}.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    })));
}
