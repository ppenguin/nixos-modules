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
  compose-wrap = (pkgs.writeShellApplication {
    name = "compose-wrap.sh";
    runtimeInputs = with pkgs; [
      podman-compose
      (podman.override { extraPackages = [ "/run/wrappers" ]; })
      fuse-overlayfs
      libcap
    ];
    text = ''
      printf "%s (PID=%s)\n" "$0" "$$"
      echo "capabilities:"
      getpcaps $$
      env
      cd "$HOME" && podman-compose "$@"
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

    security.wrappers = {
      newuidmap = lib.mkForce {
        program = "newuidmap";
        source = "${pkgs.shadow.out}/bin/newuidmap";
        # setuid = true;
        permissions = "4511";
        owner = "root";
        group = "root";
        # capabilities = "cap_setuid,cap_setgid,cap_net_raw+eip";
        capabilities = "cap_setuid=eip";
      };
    };

    systemd.services = (mapAttrs' (podname: cfg: (
      let
        homeDir = "/var/lib/${cfg.user}";
      in
      nameValuePair "pod-${podname}" rec { # here the systemd unit definition
        enable = true;
        description = "Service for ${podname} pod";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        # restartTriggers = [ cfg.apikeyFile cfg.apisecretFile ];
        path = with pkgs; [ # path doesn't seem to be available in the Exec? Or is it? env says not, but if we set environment.PATH we get "conflicting definition"
          coreutils
          podman-compose
          (podman.override { extraPackages = [ "/run/wrappers" ]; })
          "/run/wrappers"
          dbus
          bash
          su # chage???
        ];
        environment = { # check whether we have variable expansion...
          # HOME = "${homeDir}";
          # PATH = strings.concatMapStringsSep ":" (p: "${p}/bin:${p}/sbin") path;
          # XDG_DATA_DIRS = "${homeDir}/.local";
          # XDG_CONFIG_DIRS = "${homeDir}/.config";
          XDG_RUNTIME_DIR = "/run/${cfg.user}";
          # TMPDIR = "/run/${cfg.user}/tmp";
          # DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/${cfg.user}/bus";
        };
        serviceConfig = {
          Type = "exec";
          LoadCredential = lib.lists.optional (cfg.envFile != null) [ "envfile:${cfg.envFile}" ];
          # Will be available to the systemd exec env as %d/envfile
          ProtectHostname = "no";
          DynamicUser = true;
          # CapabilityBoundingSet = "CAP_SETUID CAP_SETGID CAP_SETPCAP CAP_SETFCAP CAP_NET_RAW";
          # CapabilityBoundingSet = "CAP_SETUID";
          AmbientCapabilities = "CAP_SETUID CAP_SETGID CAP_SETPCAP CAP_SETFCAP CAP_NET_RAW"; # https://unix.stackexchange.com/a/581337/395327
          RestrictSUIDSGID = false;
          StateDirectory = "${cfg.user}";
          RuntimeDirectory = "${cfg.user}";
          User = "${cfg.user}";
          Group = "${cfg.group}";
          ExecStartPre = [
            ''${pkgs.bash}/bin/bash -c 'echo "UID=$UID"; env' ''
            # ''${pkgs.dbus}/bin/dbus-run-session -- /usr/bin/env bash -c 'ls -laR /run/${cfg.user} /run/user/$UID; systemctl --user list-units' ''
            # ''${pkgs.bash}/bin/bash -c 'ls -laR /run/${cfg.user}; systemctl --user is-active dbus || systemctl --user start dbus' ''
          ];
          #   ${pkgs.coreutils}/bin/env
          # '';
          # ExecStart = ''
          #   ${compose-wrap} \
          #     ${
          #       optionalString (cfg.envFile != null) "--env-file=%d/envfile"
          #     } \
          #     --podman-args="--log-level debug" \
          #     -p "${podname}" \
          #     -f ${cfg.composeFile} \
          #     up
          # '';
          # ExecStart = ''
          #   ${pkgs.bash}/bin/bash -c 'cd $HOME && podman run -p 8080:80 docker.io/library/nginx:latest'
          # '';
          ExecStart = ''
            ${pkgs.dbus}/bin/dbus-launch -- ${pkgs.podman}/bin/podman --runroot=/run/${cfg.user}/containers --root=${homeDir}/.local/share/containers/storage --tmpdir=/run/${cfg.user}/tmp run -p 8080:80 docker.io/library/nginx:latest
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
