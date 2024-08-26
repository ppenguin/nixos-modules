# well... not bad for largely chatgpt generated... Could be more readable
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types mapAttrs' nameValuePair;
  inherit (pkgs) writeShellApplication;

  wgRefreshers = config.services.wg-refresh;

  wgrConfig = {
    options = {
      endpoint = mkOption {
        type = types.str;
        description = "Wireguard Endpoint as <host>:<port>, needs to be the same as the original wg config for this interface.";
      };
      pubkey = mkOption {
        type = types.str;
        description = "Wireguard Endpoint Public Key (used to match the endpoint within the config).";
      };
      interval = mkOption {
        type = types.str;
        default = "10min";
        description = "Endpoint IP Refresh Interval (systemd format, e.g. 10min, 1d, etc.)";
      };
    };
  };

  updateScript = let
    name = "update-wg-endpoint";
  in
    (writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [wireguard-tools bind.dnsutils gawk gnused];
      text = builtins.readFile ./update-wg-endpoint.sh;
    })
    + "/bin/${name}";
in {
  options = {
    services.wg-refresh = mkOption {
      type = types.attrsOf (types.submodule wgrConfig);
      default = {};
      description = ''
        A set of WireGuard refresh services under `wg-refresh.<interface_name>`.
        Each service corresponds to a WireGuard interface and manages DNS resolution
        updates for its peer's endpoint. (This is necessary if your peer is at a dynamic IP).

        The `refreshInterval` option sets the interval at which the WireGuard endpoint
        will be refreshed. Acceptable format is as per systemd's `OnUnitActiveSec`, e.g.,
        "30min", "1h", "2d", etc.
      '';
    };
  };

  config = mkIf (wgRefreshers != {}) {
    systemd.services = mapAttrs' (ifname: peercfg:
      nameValuePair
      "wg-refresh@${ifname}"
      {
        description = "Refresh WireGuard DNS Endpoint for ${ifname}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${updateScript} ${ifname} ${peercfg.pubkey} ${peercfg.endpoint}";
        };
      })
    wgRefreshers;

    systemd.timers = mapAttrs' (ifname: peercfg:
      nameValuePair
      "wg-refresh-${ifname}"
      {
        description = "Timer to refresh WireGuard DNS endpoint for ${ifname}";
        wantedBy = ["timers.target"];
        timerConfig = {
          Unit = "wg-refresh@${ifname}.service";
          OnBootSec = "5min"; # Start 5 minutes after boot
          OnUnitActiveSec = peercfg.interval; # Use the configured refresh interval
          Persistent = true;
        };
      })
    wgRefreshers;
  };
}
