# for convenience directly based on https://github.com/nix-community/home-manager/blob/master/modules/programs/swaync.nix
{ config, lib, pkgs, ... }:

let
  inherit (lib)
    all filterAttrs hasAttr isStorePath literalExpression optionalAttrs types;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.programs.swaync;

  jsonFormat = pkgs.formats.json { };

  # TODO: nice to have a submodule for scripts
  mkInt = name:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Value without unit.";
    };

  swayncConfig = with types;
    submodule {
      freeformType = jsonFormat.type;

      options = {

        positionX = mkOption {
          type = nullOr (enum [ "right" "left" ]);
          default = null;
          description = ''
            Horizontal position (left/right) to show the notification panel.
          '';
          example = "right";
        };

        positionY = mkOption {
          type = nullOr (enum [ "top" "bottom" ]);
          default = null;
          description = ''
            Vertical position (top/bottom) to show the notification panel.
          '';
          example = "top";
        };

#         height = mkOption {
#           type = nullOr ints.unsigned;
#           default = null;
#           example = 5;
#           description =
#             "Height to be used by the panel if possible. Leave blank for a dynamic value.";
#         };
# 
#         width = mkOption {
#           type = nullOr ints.unsigned;
#           default = null;
#           example = 5;
#           description =
#             "Width to be used by the panel if possible. Leave blank for a dynamic value.";
#         };
      };
    };
in {
  meta.maintainers = with lib.maintainers; [ berbiche ];

  options.programs.swaync = with lib.types; {
    enable = mkEnableOption "swaync";

    package = mkOption {
      type = package;
      default = pkgs.swaync;
      defaultText = literalExpression "pkgs.swaync";
      description = ''
        swaync package to use. Set to `null` to use the default package.
      '';
    };

    settings = mkOption {
      type = attrsOf swayncConfig;
      default = [ ];
      description = ''
        Configuration for swaync, see <https://github.com/ErikReider/SwayNotificationCenter#configuring>
        for supported values.
      '';
      # example = literalExpression ''
      #  '';
    };

    systemd.enable = mkEnableOption "swaync systemd integration";

    systemd.target = mkOption {
      type = str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = ''
        The systemd target that will automatically start the swaync service.

        When setting this value to `"hyprland-session.target"` (same for `sway`),
        make sure to also enable {option}`wayland.windowManager.hyprland.systemd.enable`,
        otherwise the service may never be started.
      '';
    };

    style = mkOption {
      type = nullOr (either path lines);
      default = null;
      description = ''
        CSS style for `swaync`.

        See <https://github.com/ErikReider/SwayNotificationCenter#configuring>
        for the documentation.

        If the value is set to a path literal, then the path will be used as the css file.
      '';
      # example = '''';
    };
  };

  config = let
    # Removes nulls because swaync ignores them.
    # This is not recursive.
    removeTopLevelNulls = filterAttrs (_: v: v != null);

    # TODO: check whether to remove (remnant of waybar module)
    # Makes the actual valid configuration swaync accepts
    makeConfiguration = configuration:
      removeTopLevelNulls configuration;

    # Allow using attrs for settings instead of a list in order to more easily override
    settings = if builtins.isAttrs cfg.settings then
      lib.attrValues cfg.settings
    else
      cfg.settings;

    # The clean list of configurations
    finalConfiguration = map makeConfiguration settings;

    configSource = jsonFormat.generate "swaync-config.json" finalConfiguration;

  in mkIf cfg.enable (mkMerge [
    {
      assertions = [ ];

      home.packages = [ cfg.package ];

      xdg.configFile."swaync/config" = mkIf (settings != [ ]) {
        source = configSource;
        # TODO: check if swaync reacts as expected to USR2
        onChange = ''
          ${pkgs.procps}/bin/pkill -u $USER -USR2 swaync || true
        '';
      };

      xdg.configFile."swaync/style.css" = mkIf (cfg.style != null) {
        source = if builtins.isPath cfg.style || isStorePath cfg.style then
          cfg.style
        else
          pkgs.writeText "swaync/style.css" cfg.style;
        onChange = ''
          ${pkgs.procps}/bin/pkill -u $USER -USR2 swaync || true
        '';
      };
    }

    (mkIf cfg.systemd.enable {
      systemd.user.services.swaync = {
        Unit = {
          Description =
            "A simple notification daemon with a GTK gui for notifications and the control center";
          Documentation = "https://github.com/ErikReider/SwayNotificationCenter#table-of-contents";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session-pre.target" ];
        };

        Service = {
          ExecStart = "${cfg.package}/bin/swaync";
          ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
          Restart = "on-failure";
          KillMode = "mixed";
        };

        Install = { WantedBy = [ cfg.systemd.target ]; };
      };
    })
  ]);
}