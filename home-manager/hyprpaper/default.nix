self:
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.hyprpaper;
in {
  options.services.hyprpaper = {
    enable = mkEnableOption "hyprpaper";

    package = mkOption {
      type = types.package;
      default = pkgs.hyprpaper;
    };

    configText = mkOption {
      type = types.lines;
      description = mdDoc ''
        Contents of `~/.config/hypr/hyprpaper.conf`.
        Should contain (at least?):
        ```toml
        preload = mywallpaper.jpg
        wallpaper = ,mywallpaper.jpg
        ```
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.hyprpaper =
      let
        hpconfig = pkgs.writeTextFile {
          name="hyprpaper.conf";
          text=cfg.configText;
          executable = false;
        };
      in {
        Unit = { Description = "hyprpaper wallpaper"; };
        Service = {
          ExecStart = "${cfg.package}/bin/hyprpaper -c ${hpconfig}";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "always";
        };
        Install = { WantedBy = [ "graphical-session.target" ]; };
      };
  };
}
