# Just the file from here:
#   https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/ddclient.nix
# with major modifications to just wrap the script from here:
#   https://www.instructables.com/Quick-and-Dirty-Dynamic-DNS-Using-GoDaddy/ (upgraded)
#
# Rationale: Couldn't get ddclient to work quickly enough (might be a documentation issue?), and it would be
# overkill anyway if just using GD.

self: {
  config
, pkgs
, lib
, ...
}:

let
  cfg = config.services.gddnsup;
  boolToStr = bool: if bool then "yes" else "no";
in

with lib;

{

  ###### interface

  options = {

    services.gddnsup = with types; {

      enable = mkOption {
        default = false;
        type = bool;
        description = mdDoc ''
          Whether to synchronise your machine's IP address to your GoDaddy DNS.
        '';
      };

      domainHosts = mkOption {
        default = {};
        type = attrsOf (listOf str);
        description = mdDoc ''
          Attribute set of domain names with host lists to synchronize.
          All domains must be under the same account (same GoDaddy API key).

          *Example:*
          ```nix
          domainHosts = {
              "mydomain.com" = [ "host1" "host2" ];
              "otherdom.com" = [ "host3" "host4" ];
          }
          ```
        '';
      };

      apikeyFile = mkOption {
        type = str;
        default = "/run/secrets/gddnsup/key";
        description = mdDoc ''
          Your *GoDaddy* API key (point this to e.g. a `sops-nix` managed path).
        '';
      };

      apisecretFile = mkOption {
        type = str;
        default = "/run/secrets/gddnsup/secret";
        description = mdDoc ''
          Your *GoDaddy* API secret (point this to e.g. a `sops-nix` managed path).
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

      checkip = mkOption {
        default = "https://api.ipify.org";
        type = str;
        description = mdDoc ''
          Method to determine the IP address to send to the dynamic DNS provider.
          For now does not do filtering, so a request to this address should return a plain IP!
          (So normally no need to change this.)
        '';
      };

    };
  };


  ###### implementation

  config = mkIf config.services.gddnsup.enable {
    systemd.services.gddnsup = {
      description = "GoDaddy DNS Updater";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ cfg.apikeyFile cfg.apisecretFile ];

      serviceConfig = let
        script = pkgs.writeShellApplication {
          name = "gddnsup.sh";
          text = (builtins.readFile ./gddnsup.sh);
          runtimeInputs = [ pkgs.curl ];
        };
        hostsdomains = lists.flatten (map (d: (map (h: h + "@" + d) (builtins.getAttr d cfg.domainHosts))) (attrNames cfg.domainHosts));
      in {
        # LoadCredential acts like a "proxy" to expose specific files that are only accessible by root to a DynamicUser service
        # (only for the life cycle of the service instance). Cool stuff!
        LoadCredential = [ "apikey:${cfg.apikeyFile}" "apisecret:${cfg.apisecretFile}" ];
        DynamicUser = true;
        Type = "oneshot";
        ExecStart = ''${script}/bin/gddnsup.sh '%d/apikey' '%d/apisecret' ${escapeShellArgs hostsdomains}'';
      };
    };

    systemd.timers.gddnsup = {
      description = "Run gddnsup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.interval;
        OnUnitInactiveSec = cfg.interval;
      };
    };
  };
}
