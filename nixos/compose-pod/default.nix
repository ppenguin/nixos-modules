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

  # TODO: check whether newuidmap is guaranteed in /run/wrappers/bin by NixOS or where it comes from...
  # Oh wait: https://github.com/NixOS/nixpkgs/issues/138423#issuecomment-1609849179
  # Hm, it segfaults with
  #   `/run/wrappers/bin/newuidmap 577301 0 992 1 1 231072 65536`: Assertion `!(st.st_mode & S_ISUID) || (st.st_uid == geteuid())` in NixOS's wrapper.c failed.`
  # could this be the solution? https://github.com/NixOS/nixpkgs/pull/231673
  compose-wrap = stateDir: (pkgs.writeShellApplication {
    name = "compose-wrap.sh";
    runtimeInputs = with pkgs; [ podman-compose (podman.override { extraPackages = [ "/run/wrappers" ]; }) ]; 
    text = ''
      HOME="${stateDir}" podman-compose "$@"
    '';
  }) + "/bin/compose-wrap.sh";

in {

  imports = [
    self.nixosModules.linger
  ];

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

    systemd.services = (mapAttrs' (podname: cfg: (
      let
        homeDir = "/var/lib/${cfg.user}";
      in
      nameValuePair "pod-${podname}" { # here the systemd unit definition
        enable = true;
        description = "Service for ${podname} pod";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        # restartTriggers = [ cfg.apikeyFile cfg.apisecretFile ];
        path = with pkgs; [
          bash
          podman-compose
          (podman.override { extraPackages = [ "/run/wrappers" ]; })
        ];
        environment = { # check whether we have variable expansion...
          HOME = "${homeDir}";
          # XDG_DATA_DIRS = "${homeDir}/.local";
          # XDG_CONFIG_DIRS = "${homeDir}/.config";
          XDG_RUNTIME_DIR = "/run/user/$UID";
          # DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/$UID/bus";
          CHECK_EXP = "%d%h";
        };
        serviceConfig = {
          Type = "exec";
          LoadCredential = lib.lists.optional (cfg.envFile != null) [ "envfile:${cfg.envFile}" ];
          # Will be available to the systemd exec env as %d/envfile
          DynamicUser = true;
          StateDirectory = "${cfg.user}";
          User = "${cfg.user}";
          Group = "${cfg.group}";
          ExecStartPre = ''
            ${pkgs.bash}/bin/bash -c 'printf "UID=%%s\nHOME=%%s\nXDG_RUNTIME_DIR=%%s\nCHECK_EXP=%%s\n" "$UID" "$HOME" "$XDG_RUNTIME_DIR" "$CHECK_EXP"'
          '';
          ExecStart = ''
            podman-compose \
              ${
                optionalString (cfg.envFile != null) "--env-file=%d/envfile"
              } \
              -p "${podname}" \
              -f ${cfg.composeFile} \
              up
          '';
        };
      }
    )) eachPod);

    users.users = mapAttrs' (podname: cfg:
      (nameValuePair "${cfg.user}" {
        isSystemUser = true;
        autoSubUidGidRange = true;
        group = cfg.group;
        description = "User for pod ${podname}";
      })) eachPod;

    users.groups =
      mapAttrs' (podname: cfg: (nameValuePair "${cfg.group}" { })) eachPod;

  };

}
