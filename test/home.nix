{
  inputs,
  emacs,
  pkgs,
}:
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
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
        earlyInitFile = ./early-init.el;
        config = emacs;
      };
    }
  ];
}
