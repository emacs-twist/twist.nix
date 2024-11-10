{
  pkgs,
  emacsPackage,
}:
{
  inherit pkgs emacsPackage;
  initFiles = [ ];
  lockDir = ./lock;
  registries = [ ];
}
