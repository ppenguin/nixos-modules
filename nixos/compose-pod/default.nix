self:
{ lib, config, pkgs, ... }:

with lib;

let
  eachPod = config.services.compose-pod;
  # Define the pod submodule
  podConfig = { name, config, ... }: {
    options = {
      composeFile = mkOption {
        type = types.path;
        description = "Path to the Compose file for the pod.";
      };
      user = mkOption {
        type = types.str;
        description = "The user under which to run the pod.";
      };
      group = mkOption {
        type = types.str;
        description = "The group under which to run the pod.";
      };
      envFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description =
          "Path to the environment file for the pod. (Will be loaded with systemd LoadCredentials, recommended to use e.g. a sops-nix secrets path)";
      };
    };
  };

in {

  imports = [ self.nixosModules.linger ];

  options.services.compose-pod = mkOption {
    type = types.attrsOf (types.submodule podConfig);
    default = { };
    description = "Attribute set of pods to be started.";
  };

  config = mkIf (eachPod != { }) {

    # TODO: can't we promote the below mapattrs so we have one function call and just merge the top level config attrs???
    # Actually this is not trivial, BTW the mkIf trick from https://www.youtube.com/watch?v=cZjOzOHb2ow didn't work
    # We could maybe do it like here: https://gist.github.com/udf/4d9301bdc02ab38439fd64fbda06ea43
    # but this is only slightly less verbose...

    system.activationScripts = (mapAttrs' (podname: cfg:
      (let systemdDir = "/var/lib/${cfg.user}/.config/systemd/user";
      in nameValuePair
      "enable-pod-${podname}" { # here the systemd unit definition
        text = ''
          rm -rf "${systemdDir}/"
          mkdir -p "${systemdDir}/default.target.wants"
          ln -s /etc/systemd/user/pod-${podname}.service "${systemdDir}/default.target.wants/"
          chown -R ${cfg.user}:${cfg.group} "${systemdDir}"
        '';
      })) eachPod);

    systemd.user.services = (mapAttrs' (podname: cfg:
      (let homeDir = "/var/lib/${cfg.user}";
      in nameValuePair "pod-${podname}" { # here the systemd unit definition
        enable = true;
        description = "Service for ${podname} pod";
        path = with pkgs; [ podman ];
        wantedBy = [ # "default.target"
        ]; # crappy UX, see https://github.com/NixOS/nixpkgs/issues/21460
        environment = { HOME = "${homeDir}"; };
        script = ''
          ${pkgs.podman-compose}/bin/podman-compose \
            ${
              optionalString (cfg.envFile != null) "--env-file=${cfg.envFile}"
            } \
            -f ${cfg.composeFile} \
            up
        '';
      })) eachPod);

    users.users = mapAttrs' (podname: cfg:
      (nameValuePair "${cfg.user}" {
        isSystemUser = true;
        linger = true;
        autoSubUidGidRange = true;
        group = cfg.group;
        home = "/var/lib/${cfg.user}";
        createHome = true;
        description = "User for pod ${podname}";
      })) eachPod;

    users.groups =
      mapAttrs' (podname: cfg: (nameValuePair "${cfg.group}" { })) eachPod;

  };

}
