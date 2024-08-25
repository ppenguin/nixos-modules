# well... not bad for largely chatgpt generated... Could be more readable
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Define the generic update script for a single peer
  updateScript = with pkgs;
    writeShellApplication {
      name = "update-wg-endpoint.sh";
      runtimeInputs = [wireguard-tools bind gawk];
      text = builtins.readFile ./update-wg-endpoint.sh;
    };
in {
  options.systemd.services.wg-refresh = with lib;
    mkOption {
      type = types.attrsOf (types.attrsOf (types.attrs
        // {
          refreshInterval = types.str;
          peer = types.attrsOf types.str;
        }));
      description = ''
        A set of WireGuard refresh services under `wg-refresh.<interface_name>`.
        Each service corresponds to a WireGuard interface and manages DNS resolution
        updates for its single peer's endpoint.

        The `refreshInterval` option sets the interval at which the WireGuard endpoint
        will be refreshed. Acceptable format is as per systemd's `OnUnitActiveSec`, e.g.,
        "30min", "1h", "2d", etc.

        The `peer` option should contain an attribute set with `PublicKey` and `Endpoint` to specify the peer details.
      '';
      default = {};
    };

  config = lib.mkIf (config.systemd.services.wg-refresh != {}) {
    systemd.services = lib.foldl' (acc: interfaceName: interfaceConfig: let
      inherit (interfaceConfig) peer;
      peerPublicKey = peer.PublicKey;
      peerEndpoint = peer.Endpoint;
    in
      acc
      // {
        "wg-refresh-${interfaceName}" = {
          description = "Refresh WireGuard DNS Endpoint for ${interfaceName}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${updateScript} ${interfaceName} ${peerPublicKey} ${peerEndpoint}";
          };
        };
      }) {} (lib.attrNames config.systemd.services.wg-refresh) (lib.attrValues config.systemd.services.wg-refresh);

    systemd.timers = lib.foldl' (acc: interfaceName: interfaceConfig: let
      refreshInterval = lib.getAttr "refreshInterval" interfaceConfig "10min"; # Default to 30 minutes if not specified
    in
      acc
      // {
        "wg-refresh-${interfaceName}" = {
          description = "Timer to refresh WireGuard DNS endpoint for ${interfaceName}";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5min"; # Start 5 minutes after boot
            OnUnitActiveSec = refreshInterval; # Use the configured refresh interval
            Persistent = true;
          };
          unit = "wg-refresh-${interfaceName}.service";
        };
      }) {} (lib.attrNames config.systemd.services.wg-refresh) (lib.attrValues config.systemd.services.wg-refresh);
  };
}
