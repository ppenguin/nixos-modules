# yacfuc (yet another cloudflare update client)
# Based on cloudflare-dynamic-dns (https://github.com/Zebradil/cloudflare-dynamic-dns)
# ... because the existing nixos modules are based on
# two clients that are hit&miss (either lag behind CF's erratic API updates
# or don't build when overridden)
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.yacfuc;
  # boolToStr = bool: if bool then "yes" else "no";
in
  with lib; {
    ###### interface

    # TODO: cover rest of the options of cloudflare-dynamic-dns

    options = {
      services.yacfuc = with types; {
        enable = lib.mkEnableOption "(Yet another Cloudflare Dynamic DNS Client";

        package = lib.mkPackageOption pkgs "cloudflare-dynamic-dns" {};

        extraPackages = mkOption {
          type = listOf package;
          default = [pkgs.curl];
          description = mdDoc ''
            Packages that you need in the service's environment.
            (For `ipcmd`, `curl` by default.)
          '';
        };

        domains = mkOption {
          type = listOf str;
          description = mdDoc ''
            List of domain names to update.
            All domains must be under the same account (same API token).
          '';
        };

        apiTokenFile = mkOption {
          type = str;
          default = "/run/secrets/yacfuc/token";
          description = mdDoc ''
            Your *Cloudflare* API token (point this to e.g. a `sops-nix` managed path).
            It *must* have the format
            ```
            CFDDNS_TOKEN=cloudflare-api-token
            ```
          '';
        };

        interval = mkOption {
          default = "10min";
          type = str;
          description = mdDoc ''
            The interval at which to run the check and update.
            See {command}`man 7 systemd.time` for the format.
          '';
        };

        ipcmd = mkOption {
          default = "curl -fsSL https://api.ipify.org";
          type = nullOr str;
          description = mdDoc ''
            Method to determine the IP address to send to the dynamic DNS provider.
            For now does not do filtering, so this command should return a plain IP!
          '';
        };

        iface = mkOption {
          default = null;
          type = nullOr str;
          description = mdDoc ''
            Network interface to get the IP from.
            Not used per default (in favour of `ipcmd`).
            At least one of `iface` and `ipcmd` must be set.
          '';
        };

        stack = mkOption {
          default = "ipv4";
          type = str;
          description = mdDoc ''
            IP stack version: ipv4 or ipv6.
          '';
        };
      };
    };

    ###### implementation

    config = mkIf config.services.yacfuc.enable {
      assertions = [
        {
          asssertion = cfg.iface != null || cfg.ipcmd != null;
          message = "At least one of `ipcmd` or `iface` must be set!";
        }
      ];

      systemd.services.yacfuc = {
        description = "Yet Another CloudFlare (DNS) Updater Client";
        wantedBy = ["multi-user.target"];
        requires = ["network-online.target"];
        after = ["network-online.target"];
        restartTriggers = [cfg.apiTokenFile];

        serviceConfig = let
          fif =
            if (cfg.iface != null)
            then "--iface='${cfg.iface}'"
            else "";
          fipc =
            if (cfg.ipcmd != null)
            then "--ipcmd='${cfg.ipcmd}'"
            else "";
          fdom = "--domains='${concatStringsSep " " cfg.domains}'";
          fhostid = "--hostid='${config.networking.hostname}'";
          fstack = "--stack=${cfg.stack}";
          flags = concatStringsSep " " [fif fipc fdom fhostid fstack];
        in {
          # LoadCredential acts like a "proxy" to expose specific files
          # that are only accessible by root to a DynamicUser service
          # (only for the life cycle of the service instance). Cool stuff!
          LoadCredential = ["apitoken:${cfg.apiTokenFile}"];
          DynamicUser = true;
          Type = "oneshot";
          EnvironmentFile = "%d/apitoken";
          ExecStart = "${lib.getExe cfg.package} ${flags}";
        };
      };

      systemd.timers.yacfuc = {
        description = "Run yacfuc";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = cfg.interval;
          OnUnitInactiveSec = cfg.interval;
        };
      };
    };
  }
