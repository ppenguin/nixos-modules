# HM module for styli.sh service
# Supports timed execution of styli.sh with (for now) selected options configurable
self: {
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.stylish;
  prefixQuotedValOrEmptyNull = str: pfx:
    if str != null
    then ''${pfx}"${str}"''
    else "";
in
  with lib;
  with builtins; {
    imports = [];

    ###### interface

    options = {
      services.stylish = with types; {
        enable = mkEnableOption "stylish";

        package = mkOption {
          type = types.package;
          default = pkgs.stylish;
          defaultText = literalExpression "pkgs.stylish";
          example = literalExpression "pkgs.stylish";
          description = "The package to use for the styli.sh script";
        };

        search = mkOption {
          type = nullOr str;
          default = null;
          description = mdDoc ''
            Search string (value used for `-s`|`--search` flag)
          '';
        };

        flags = mkOption {
          type = listOf str;
          default = [];
          description = mdDoc ''
            Flags for `styli.sh` (list of string).
            (See [`styli.sh` documentation](https://github.com/thevinter/styli.sh))
          '';
          example = literalExpression ''[ "-w 3840" "-h 2160" ]'';
        };

        env = mkOption {
          type = listOf str;
          default = [];
          description = mdDoc ''
            Environment variables for styli.sh (list of string).
            If you use (the default) unsplash as a wallpaper provider,
            you should at least set UNSPLASH_ACCESS_KEY.
          '';
        };

        refreshInterval = mkOption {
          default = "0";
          type = str;
          description = mdDoc ''
            If set, `styli.sh` will be executed with this interval to refresh the wallpaper.
            (Interval in the format of [`systemd.time`](https://www.freedesktop.org/software/systemd/man/systemd.time.html))
          '';
          example = literalExpression "30min";
        };
      };
    };

    ###### implementation

    config = mkIf config.services.stylish.enable {
      assertions = [
        (hm.assertions.assertPlatform "services.stylish" pkgs platforms.linux)
      ];

      # include in user env for manual execution
      # TODO: (for fun) make included optional packages dependent on plugins command line
      # (or improve plugin option interface of module)
      # Or: (simpler): add option for extra packages (seems to be also some kind of convention already)
      # And: add service dependencies (so we can e.g. make sure that hyprpaper service is started before stylish with hyprpaper plugin runs)
      home.packages = [cfg.package];

      systemd.user.services.stylish = {
        Unit = {
          Description = "styli.sh set wallpaper service";
          After = ["graphical.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${cfg.package}/bin/styli.sh ${
            prefixQuotedValOrEmptyNull cfg.search "-s "
          } ${
            if cfg.flags != null
            then (concatStringsSep " " cfg.flags)
            else ""
          }";
          environment = cfg.env;
        };

        Install = {WantedBy = ["graphical.target"];};
      };

      systemd.user.timers.stylish = {
        # enable = cfg.refreshInterval != "0";
        Unit = {Description = "Run styli.sh at refresh interval";};

        Install = {WantedBy = ["timers.target"];};

        Timer = {
          OnUnitInactiveSec = cfg.refreshInterval;
          Unit = "stylish.service";
        };
      };
    };
  }
