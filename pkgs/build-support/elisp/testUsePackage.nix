with builtins;
let
  pkgs = import <nixpkgs> { };
  fromElisp = import (fetchTree (fromJSON (readFile ../../../flake.lock)).nodes.fromElisp.locked) {
    inherit pkgs;
  };
  parseUsePackages = import ./parseUsePackages.nix {
    inherit (pkgs) lib;
    inherit fromElisp;
  };

  validateConfig = import ./validateConfig.nix { inherit (pkgs) lib; };
in
pkgs.lib.runTests {
  testDirect = {
    expr = validateConfig (parseUsePackages { } ''
      (use-package hello)

      (use-package bye :ensure t)
    '');
    expected = {
      elispPackages = [ "bye" ];
      elispPackagePins = { };
      systemPackages = [ ];
    };
  };

  testEnsureAnother = {
    expr = parseUsePackages { } ''
      (use-package zaijian :ensure bye)
    '';
    expected = {
      elispPackages = [ "bye" ];
      elispPackagePins = { };
      systemPackages = [ ];
    };
  };

  testPin = {
    expr = parseUsePackages { } ''
      (use-package hello
        :ensure t
        :pin american)
    '';
    expected = {
      elispPackages = [ "hello" ];
      elispPackagePins = {
        hello = "american";
      };
      systemPackages = [ ];
    };
  };
}
