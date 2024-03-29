# from upstream, improved with extraFlags
# TODO: support password file, enumerated encryption scheme, ...
# TODO: add client
self:
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.go-shadowsocks2.server;
in {
  options.services.go-shadowsocks2.server = {
    enable = mkEnableOption (lib.mdDoc "go-shadowsocks2 server");

    listenAddress = mkOption {
      type = types.str;
      description = lib.mdDoc "Server listen address or URL";
      example = "ss://AEAD_CHACHA20_POLY1305:your-password@:8488";
    };

    extraFlags = mkOption {
      type = types.str;
      description = lib.mdDoc "Extra flags used to start daemon";
      example =
        "-verbose -plugin \${pkgs.shadowsocks-v2ray-plugin}/bin/v2ray-plugin -plugin-opts 'server'";
      default = "";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.go-shadowsocks2-server = {
      description = "go-shadowsocks2 server";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart =
          "${pkgs.go-shadowsocks2}/bin/go-shadowsocks2 -s '${cfg.listenAddress}' ${cfg.extraFlags}";
        DynamicUser = true;
      };
    };
  };
}
