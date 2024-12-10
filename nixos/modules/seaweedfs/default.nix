{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with builtins; let
  cfg = config.services.seaweedfs;
in {
  options = {
    services.seaweedfs = {
      enable = mkEnableOption (lib.mdDoc "SeaweedFS Server");

      package = mkPackageOption pkgs "seaweedfs" {};

      user = mkOption {
        type = types.str;
        default = "seaweed";
        example = "seaweed";
        description = lib.mdDoc ''
          User to run the server as
        '';
      };

      group = mkOption {
        type = types.str;
        default = "seaweed";
        example = "seaweed";
        description = lib.mdDoc ''
          Group to run the server as
        '';
      };

      ip = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "192.168.1.123";
        description = lib.mdDoc ''
          IP address or server name.
          (Be careful if your hostname primarily resolves to an ipv6 address and the volume server only listens on ipv4!)
        '';
      };

      ipBind = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "192.168.1.123";
        description = lib.mdDoc ''
          IP address to bind to (Defaults to value of `ip` option)
        '';
      };

      masterPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "9333";
        description = lib.mdDoc ''
          Master port (default `9333`)
        '';
      };

      masterPortGrpc = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "9334";
        description = lib.mdDoc ''
          Master GRPC port
        '';
      };

      volumePort = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "8080";
        description = lib.mdDoc ''
          Volume server port HTTP (default `8080`)
        '';
      };

      volumePortGrpc = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "8084";
        description = lib.mdDoc ''
          Volume server GRPC listen port
        '';
      };

      filerPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "8888";
        description = lib.mdDoc ''
          Filer server port HTTP (default `8888`)
        '';
      };

      filerPortGrpc = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "8884";
        description = lib.mdDoc ''
          Filer server GRPC listen port
        '';
      };

      dirs = mkOption {
        type = with types; listOf str;
        example = ''[ "/path/one" "/path/two" ]'';
        description = lib.mdDoc ''
          Directories used for volume storage
        '';
      };

      volumeDirIdx = mkOption {
        type = types.str;
        example = "/path/idx";
        description = lib.mdDoc ''
          Directory to store .idx files
        '';
      };

      volumeMax = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "10";
        description = lib.mdDoc ''
          Maximum number of volumes
        '';
      };

      extraArgs = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "-master.raftHashicorp";
        description = lib.mdDoc ''
          Additional arguments to the server that this module not (yet) supports
        '';
      };

      startMaster = mkOption {
        type = types.bool;
        default = true;
        description = lib.mdDoc ''
          whether to start a master server (`-master`)
        '';
      };

      startVolume = mkOption {
        type = types.bool;
        default = true;
        description = lib.mdDoc ''
          whether to start volume server (`-volume`)
        '';
      };

      startFiler = mkOption {
        type = types.bool;
        default = true;
        description = lib.mdDoc ''
          whether to start `filer` (`-filer`)
        '';
      };

      metricsIp = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "192.168.1.123";
        description = lib.mdDoc ''
          IP address to serve metrics
        '';
      };

      metricsPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = "9199";
        description = lib.mdDoc ''
          IP port to serve metrics
        '';
      };
    };

    # TODO: add more options
  };

  config = mkIf cfg.enable {
    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
      };
      groups.${cfg.group} = {};
    };

    systemd.tmpfiles.rules = map (
      d: "d ${d} 0770 ${cfg.user} ${cfg.group} - -"
    ) (cfg.dirs ++ [cfg.volumeDirIdx]);

    systemd.services.seaweedfs = {
      wantedBy = ["multi-user.target"];
      after = [
        "network.target"
      ];

      serviceConfig = {
        Type = "exec";
        ExecStart = [
          (
            "${cfg.package}/bin/weed server"
            + " -master=${boolToString cfg.startMaster} -volume=${boolToString cfg.startVolume} -filer=${boolToString cfg.startFiler}"
            + lib.optionalString (cfg.ip != null) " -ip=${cfg.ip}"
            + lib.optionalString (cfg.ipBind != null) " -ip.bind=${cfg.ipBind}"
            + " -dir="
            + (concatStringsSep "," cfg.dirs)
            + lib.optionalString (cfg.volumeDirIdx != null) " -volume.dir.idx=${cfg.volumeDirIdx}"
            + lib.optionalString (cfg.volumeMax != null) " -volume.max=${toString cfg.volumeMax}"
            + lib.optionalString (cfg.masterPort != null) " -master.port=${toString cfg.masterPort}"
            + lib.optionalString (cfg.masterPortGrpc != null) " -master.port.grpc=${toString cfg.masterPortGrpc}"
            + lib.optionalString (cfg.volumePort != null) " -volume.port=${toString cfg.volumePort}"
            + lib.optionalString (cfg.volumePortGrpc != null) " -volume.port.grpc=${toString cfg.volumePortGrpc}"
            + lib.optionalString (cfg.filerPort != null && cfg.startFiler) " -filer.port=${toString cfg.filerPort}"
            + lib.optionalString (cfg.filerPortGrpc != null && cfg.startFiler) " -filer.port.grpc=${toString cfg.filerPortGrpc}"
            + lib.optionalString (cfg.metricsIp != null) " -metricsIp=${cfg.metricsIp}"
            + lib.optionalString (cfg.metricsPort != null) " -metricsPort=${toString cfg.metricsPort}"
          )
        ];
      };
    };
  };
}
