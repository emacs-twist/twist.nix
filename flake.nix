{
  description = "Source-based Emacs Lisp build machinery";

  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix/50cfce93606c020b9e69dce24f039b39c34a4c2d";
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
  inputs.flake-no-path.url = "github:akirak/flake-no-path";

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , pre-commit-hooks
    , ...
    } @ inputs:
    ({
      lib = import ./lib {
        inherit (nixpkgs) lib;
        fromElisp = import inputs.fromElisp {
          pkgs = { inherit (nixpkgs) lib; };
        };
      };
      overlay = _self: import ./pkgs inputs;
    }
    //
    (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    {
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            nix-linter.enable = true;
            flake-no-path = {
              enable = true;
              name = "Ensure that flake.lock does not contain a local path";
              entry = "${
                inputs.flake-no-path.packages.${system}.flake-no-path
              }/bin/flake-no-path";
              files = "flake\.lock$";
              pass_filenames = true;
            };
          };
        };
      };
      devShell = nixpkgs.legacyPackages.${system}.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    })));
}
