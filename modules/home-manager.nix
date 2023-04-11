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

  configurationRevision = emacs-config.configurationRevision;

  initFile = pkgs.runCommandLocal "init.el" {} ''
    mkdir -p $out
    touch $out/init.el
    for file in ${builtins.concatStringsSep " " emacs-config.initFiles}
    do
      cat "$file" >> $out/init.el
      echo >> $out/init.el
    done
  '';

  wrapper =
    pkgs.runCommandLocal cfg.name {
      propagatedBuildInputs = [
        emacs-config
      ];
      nativeBuildInputs = [
        pkgs.makeWrapper
      ];
    } ''
      mkdir -p $out/bin

      makeWrapper ${emacs-config}/bin/emacs $out/bin/${cfg.name} \
        --add-flags --init-directory="${config.home.homeDirectory}/${cfg.directory}"

      ${
        lib.optionalString cfg.emacsclient.enable
        "ln -t $out/bin -s ${emacs-config.emacs}/bin/emacsclient"
      }
    '';

  desktopItem = pkgs.makeDesktopItem {
    name = cfg.name;
    inherit (cfg.desktopItem) desktopName mimeTypes;
    comment = "Edit text";
    genericName = "Text Editor";
    exec = "${cfg.name} %F";
    icon = "emacs";
    startupNotify = true;
    startupWMClass = "Emacs";
    categories = ["TextEditor" "Development"];
  };
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

      wrapper = mkOption {
        type = types.package;
        description = "The wrapper derivation";
        readOnly = true;
        default = wrapper;
      };

      emacsclient = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to install emacsclient";
        };
      };

      serviceIntegration = {
        enable = mkEnableOption (lib.mdDoc ''
          Enable service integration. For now, only systemd is supported.
        '');
      };

      icons = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to install Emacs icons";
          default = true;
        };
      };

      desktopItem = {
        desktopName = mkOption {
          type = types.str;
          description = "Long name of the desktop item";
          default = "Emacs";
        };

        mimeTypes = mkOption {
          type = types.listOf types.str;
          description = "List of mime types associated with the wrapper";
          default = ["text/plain" "inode/directory"];
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [wrapper]
      ++ lib.optional cfg.icons.enable emacs-config.icons
      ++ lib.optional (!pkgs.stdenv.isDarwin) (pkgs.runCommandLocal "${cfg.name}-desktop-item" {
          nativeBuildInputs = [pkgs.copyDesktopItems];
          desktopItems = desktopItem;
        } ''
          runHook postInstall
        '');

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

    services.emacs = lib.mkIf cfg.serviceIntegration.enable {
      enable = true;
      package = wrapper;
    };

    systemd.user.services.emacs = lib.mkIf (cfg.serviceIntegration.enable
      && pkgs.stdenv.isLinux) {
      Service = {
        ExecReload = "${wrapper}/bin/emacsclient --eval '(twist-push-digest \"${
          emacs-config.emacsWrapper.elispEnvDigestPath
        }\"${
          lib.optionalString (configurationRevision != null)
          " \"${configurationRevision}\""
        })'";
      };
    };
  };
}
