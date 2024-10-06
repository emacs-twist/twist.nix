{
  description = "Source-based Emacs Lisp build machinery";

  inputs.elisp-helpers.url = "github:emacs-twist/elisp-helpers";

  outputs = {...} @ inputs: {
    # lib is experimental at present, so it may be removed in the future.
    lib = import ./lib inputs;
    overlays = {
      default = import ./pkgs inputs;
    };
    homeModules = {
      emacs-twist = ./modules/home-manager.nix;
    };
    templates = {
      default = {
        description = "A basic configuration for use-package";
        path = ./template;
      };
    };
  };
}
