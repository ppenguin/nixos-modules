# for convenience directly based on https://github.com/nix-community/home-manager/blob/master/modules/programs/swaync.nix
self:
{ config, lib, pkgs, ... }:

let
  inherit (lib)
    all filterAttrs hasAttr isStorePath literalExpression optionalAttrs types;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.programs.swaync;

  jsonFormat = pkgs.formats.json { };

  # TODO: nice to have a submodule for scripts

  mkOptAttrs = fun: names:
    lib.foldr (a: b: a // b) { }
    (map (n: lib.genAttrs [ n ] (_: (fun n))) names);

  mkIntPxOpt = name:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Value in pixels";
    };

  mkIntMsOpt = name:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Time value in milliseconds";
    };

  mkIntSecsOpt = name:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Time value in seconds";
    };

  mkBoolOpt = name:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Boolean (true or false).";
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

        image-visibility = mkOption {
          type = nullOr (enum [ "always" "when-available" ]); # TODO: more?
          default = null;
          description = ''
            When to show images.
          '';
          example = "when-available";
        };

        # TODO (maybe): more useful widget defs: convert widgetsConfig = { <title>: {config ...}; } => { widgets: [ title, ... ], widget-config: { <title>: { config}, ... }

        # TODO: one should probably be able to auto generate all options of a certain type from a list of names?
        # => below implemented, but doesn't work yet... TODO: fix
      }
      /* // mkOptAttrs mkBoolOpt [ "keyboard-shortcuts" "fit-to-screen" "hide-on-clear" "hide-on-action" "script-fail-notify" ] # auto-generated options (nifty trick)
         // mkOptAttrs mkIntPxOpt
           (map(n: "control-center-margin-${n}" ) [ "top" "bottom" "right" "left" ])
           ++ (lib.flatten (map(n: map(d: "${n}-${d}") [ "width" "height" ]) [ "control-center" "notification-body-image" "notification-window" ]))
           ++ [ "notification-icon-size" ]
         // mkOptAttrs mkIntMsOpt [ "transition-time" ]
         // mkOptAttrs mkIntSecsOpt [ "timeout" "timeout-low" "timeout-warning" ]
      */
      ;
    };
in {
  meta.maintainers = with lib.maintainers; [ ppenguin ];

  options.programs.swaync = with lib.types; {
    enable = mkEnableOption "swaync";

    package = mkOption {
      type = package;
      default = pkgs.swaynotificationcenter;
      defaultText = literalExpression "pkgs.swaynotificationcenter";
      description = ''
        swaync package to use. Omit (or set to `null`) to use the default package.
      '';
    };

    settings = mkOption {
      type = attrsOf swayncConfig;
      default = { };
      description = ''
        Configuration for swaync, see <https://github.com/ErikReider/SwayNotificationCenter#configuring>
        for supported values.
        Given as an attrset of arbitrary keys with a value that's either a json string (can also be imported from a file)
        or as nix-style JSON values.
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
    makeConfiguration = configuration: removeTopLevelNulls configuration;

    # Allow using attrs for settings instead of a list in order to more easily override
    settings = if builtins.isAttrs cfg.settings then
      lib.attrValues cfg.settings
    else
      cfg.settings;

    # The merged config attributes (from all sources)
    finalConfiguration = lib.foldr (a: b: a // b) {
      "$schema" = "${cfg.package}/etc/xdg/swaync/configSchema.json";
    } settings;

    configSource = jsonFormat.generate "swaync-config.json" finalConfiguration;

  in mkIf cfg.enable (mkMerge [
    {
      assertions = [ ];

      home.packages = [ cfg.package ];

      xdg.configFile."swaync/config.json" = mkIf (settings != [ ]) {
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
          Documentation =
            "https://github.com/ErikReider/SwayNotificationCenter#table-of-contents";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session-pre.target" ];
        };

        Service = {
          ExecStart = ''
            ${cfg.package}/bin/swaync --config "${config.xdg.configHome}/swaync/config.json" --style "${config.xdg.configHome}/swaync/style.css"'';
          ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
          Restart = "always";
          KillMode = "mixed";
        };

        Install = { WantedBy = [ cfg.systemd.target ]; };
      };
    })
  ]);
}
