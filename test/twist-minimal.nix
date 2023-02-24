{
  emacsTwist,
  emacs-28-2,
}:
emacsTwist {
  emacsPackage = emacs-28-2.overrideAttrs (_: {version = "20221201.0";});
  initFiles = [];
  lockDir = ./lock;
  inventories = [];
}
