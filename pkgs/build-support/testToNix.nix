with builtins; let
  pkgs = import <nixpkgs> {};

  toNix = import ./toNix.nix {inherit (pkgs) lib;};
in
  pkgs.lib.runTests {
    testParse = {
      expr = toNix {
        description = "description";
        inputs = {
          bind-key = {
            flake = false;
            owner = "jwiegley";
            repo = "use-package";
            type = "github";
          };
          "bind-key+" = {
            flake = false;
            owner = "jwiegley";
            repo = "use-package";
            type = "github";
          };
        };
        outputs = {...}: {};
      };
      expected = ''
        { description = "description"; inputs = { bind-key = { flake = false; owner = "jwiegley"; repo = "use-package"; type = "github"; }; "bind-key+" = { flake = false; owner = "jwiegley"; repo = "use-package"; type = "github"; }; }; outputs = <LAMBDA>; }'';
    };
  }
