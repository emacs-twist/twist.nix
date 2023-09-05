{
  emacsTwist,
  emacsPackage,
}:
emacsTwist {
  inherit emacsPackage;
  initFiles = [];
  lockDir = ./lock;
  inventories = [];
}
