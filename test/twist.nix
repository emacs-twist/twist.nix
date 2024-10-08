{
  pkgs,
  emacsPackage,
  inputs,
  initialLibraries ? null,
}:
{
  inherit pkgs;
  # Use nix-emacs-ci which is more lightweight than a regular build
  inherit emacsPackage;
  # In an actual configuration, you would use this:
  # emacs = pkgs.emacsPgtkGcc.overrideAttrs (_: { version = "29.0.50"; });
  initFiles = [
    ./init.el
  ];
  lockDir = ./lock;
  inherit initialLibraries;
  registries = [
    {
      type = "elpa";
      path = inputs.gnu-elpa.outPath + "/elpa-packages";
      core-src = emacsPackage.src;
      auto-sync-only = true;
    }
    {
      name = "melpa";
      type = "melpa";
      path = inputs.melpa.outPath + "/recipes";
    }
    {
      type = "elpa";
      path = inputs.nongnu.outPath + "/elpa-packages";
    }
    {
      name = "gnu";
      type = "archive";
      url = "https://elpa.gnu.org/packages/";
    }
    {
      name = "emacsmirror";
      type = "gitmodules";
      path = inputs.epkgs.outPath + "/.gitmodules";
    }
  ];
  inputOverrides = {
    bbdb = _: super: {
      files = builtins.removeAttrs super.files [
        "bbdb-notmuch.el"
        "bbdb-vm.el"
        "bbdb-vm-aux.el"
      ];
    };
  };
  postCommandOnGeneratingLockDir = ''
    touch test/lock-success
  '';
}
