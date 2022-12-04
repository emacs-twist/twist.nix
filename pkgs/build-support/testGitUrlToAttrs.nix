with builtins; let
  pkgs = import <nixpkgs> {};

  gitUrlToAttrs = import ./gitUrlToAttrs.nix;
in
  pkgs.lib.runTests {
    testParse = {
      expr = gitUrlToAttrs "https://github.com/emacsmirror/2048-game";
      expected = {
        type = "github";
        owner = "emacsmirror";
        repo = "2048-game";
      };
    };
  }
