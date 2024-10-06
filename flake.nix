{
  description = "Source-based Emacs Lisp build machinery";

  inputs.elisp-helpers.url = "github:emacs-twist/elisp-helpers";

  outputs = {...} @ inputs: {
    # The APIs under lib is unstable at present. It may undergo changes in the
    # future.
    lib = import ./lib inputs;
    # The overlay API is deprecated.
    overlays = {
      default = import ./pkgs/overlay.nix inputs;
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
