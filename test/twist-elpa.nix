{
  emacsTwist,
  emacsPackage,
  inputs,
  initialLibraries ? null,
}:
emacsTwist {
  # Use nix-emacs-ci which is more lightweight than a regular build
  inherit emacsPackage;
  # In an actual configuration, you would use this:
  # emacs = pkgs.emacsPgtkGcc.overrideAttrs (_: { version = "29.0.50"; });
  initFiles = [
    ./init-elpa.el
  ];
  lockDir = ./lock-elpa;
  inherit initialLibraries;
  registries = [
    {
      type = "elpa";
      path = inputs.gnu-elpa.outPath + "/elpa-packages";
      core-src = emacsPackage.src;
      auto-sync-only = true;
    }
    {
      type = "elpa";
      path = inputs.nongnu.outPath + "/elpa-packages";
    }
  ];
  inputOverrides = import ./overrides.nix;
  postCommandOnGeneratingLockDir = ''
    touch test/lock-success-elpa
  '';
}
