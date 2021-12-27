{
  description = "Source-based Emacs Lisp build machinery";

  inputs.elisp-helpers = {
    url = "github:akirak/nix-elisp-helpers";
    flake = false;
  };
  inputs.fromElisp = {
    url = "github:talyz/fromElisp";
    flake = false;
  };

  outputs = { ... } @ inputs:
    {
      overlay = import ./pkgs inputs;
    };
}
