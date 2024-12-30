{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  cfg = config.services.rpi4-pwmfan;
  rpi4-pwmfan-pkg = pkgs.callPackage ../../../pkgs/rpi4-pwmfan {};
in {
  options = {
    services.rpi4-pwmfan = {
      enable = mkEnableOption "Enable RPi4 PWM Fan (automatic CPU temperature based fan control)";
      package = mkPackageOption (pkgs // {rpi4-pwmfan = rpi4-pwmfan-pkg;}) "rpi4-pwmfan" {};
    };
  };

  config = mkIf cfg.enable {
    systemd.services.rpi4-pwmfan = {
      description = "RPi4 PWM Fan (automatic CPU temperature based fan control)";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/rpi4-pwmfan.py";
        Restart = "on-failure";
      };
    };
  };
}
