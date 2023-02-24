{
  inputs,
  emacs,
  pkgs,
  lib,
}:
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs lib;
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
        createInitFile = true;
        earlyInitFile = ./early-init.el;
        config = emacs;
      };
    }
  ];
}
