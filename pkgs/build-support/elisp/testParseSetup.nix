with builtins;
let
  pkgs = import <nixpkgs> { };
  fromElisp = import (fetchTree (fromJSON (readFile ../../../flake.lock)).nodes.fromElisp.locked) {
    inherit pkgs;
  };
  parseSetup = import ./parseSetup.nix {
    inherit (pkgs) lib;
    inherit fromElisp;
  } { };
in
pkgs.lib.runTests {
  testFlat = {

    expr = parseSetup ''

      (setup (:package dash))

      (setup magit
        (:package magit))

      (setup (:package aftermath afterlife))

    '';

    expected = {
      elispPackages = [
        "dash"
        "magit"
        "aftermath"
        "afterlife"
      ];
    };

  };

  testNested = {

    expr = parseSetup ''

      (setup (:package university)
        (:load-after good-scores
          (:package master-degree)
        (:load-after master-degree
          (:load-after job-experience
            (:package work-visa))
          (:load-after ph-d
            (:package work-visa)))))

      (setup t
        (:load-after million-dollars
          (:package retirement)))

      (setup (:package china)
        (:load-after car
          (:load-after house
            (:package marriage))))

    '';

    expected = {
      elispPackages = [
        "university"
        "china"
        "retirement"
        "master-degree"
        "marriage"
        "work-visa"
      ];
    };

  };
}
