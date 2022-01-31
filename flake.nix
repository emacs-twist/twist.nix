{
  description = "Source-based Emacs Lisp build machinery";

  inputs.elisp-helpers = {
    url = "github:emacs-twist/elisp-helpers";
    flake = false;
  };
  inputs.fromElisp = {
    url = "github:talyz/fromElisp";
    flake = false;
  };

  outputs = { ... } @ inputs:
    {
      # lib is experimental at present, so it may be removed in the future.
      lib = import ./lib inputs;
      overlay = import ./pkgs inputs;

      defaultTemplate = {
        description = "A basic configuration for use-package";
        path = ./template;
      };
    };
}
