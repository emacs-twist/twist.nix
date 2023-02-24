/*
home-manager module that provides an installation of Emacs
*/
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkOptionType types;
  cfg = config.programs.emacs-twist;

  emacs-config = cfg.config;

  initFile = pkgs.runCommandLocal "init.el" {} ''
    mkdir -p $out
    touch $out/init.el
    for file in ${builtins.concatStringsSep " " emacs-config.initFiles}
    do
      cat "$file" >> $out/init.el
      echo >> $out/init.el
    done
  '';

  wrapper = pkgs.writeShellScriptBin cfg.name ''
    exec ${emacs-config}/bin/emacs --init-directory="$HOME/${cfg.directory}" "$@"
  '';

  emacsclient =
    pkgs.runCommandLocal "emacsclient" {
      propagatedBuildInputs = [emacs-config.emacs];
    } ''
      mkdir -p $out/bin
      ln -t $out/bin -s ${emacs-config.emacs}/bin/emacsclient
    '';
in {
  options = {
    programs.emacs-twist = {
      enable = mkEnableOption "Emacs Twist";

      name = mkOption {
        type = types.str;
        description = "Name of the wrapper script";
        default = "emacs";
        example = "my-emacs";
      };

      directory = mkOption {
        type = types.str;
        description = "Relative path in string to user-emacs-directory from the home directory";
        default = ".config/emacs";
        example = ".local/share/emacs";
      };

      createInitFile = mkOption {
        type = types.bool;
        description = "Whether to create init.el in the directory";
        default = false;
      };

      earlyInitFile = mkOption {
        type = types.nullOr types.path;
        description = ''
          Path to early-init.el.

          If the value is nil, no file is created in the directory.
        '';
        default = null;
      };

      config = mkOption {
        type = mkOptionType {
          name = "twist";
          description = "Configuration of emacs-twist";
          check = c: c ? initFiles && c ? emacs;
        };
      };

      emacsclient = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to install emacsclient";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [wrapper] ++ lib.optional cfg.emacsclient.enable emacsclient;

    home.file = builtins.listToAttrs (
      (lib.optional cfg.createInitFile {
        name = "${cfg.directory}/init.el";
        value = {
          source = "${initFile}/init.el";
        };
      })
      ++ (lib.optional (cfg.earlyInitFile != null) {
        name = "${cfg.directory}/early-init.el";
        value = {
          source = cfg.earlyInitFile;
        };
      })
    );
  };
}
