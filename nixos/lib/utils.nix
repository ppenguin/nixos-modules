{
  pkgs,
  lib,
  ...
}:
# rec needed because some functions refer to others in this file
rec {
  inherit (import ./_borg.nix {inherit sopsCatSecretCmd;}) borgStandardJob;
  inherit
    (import ./_container.nix {inherit pkgs lib sopsCatSecretCmd;})
    podmanSecretEnvSops
    mkDbInitScript
    mkDbExecSQLScript
    mkDbUserExecSQLScript
    mkPodmanImgPullLatestScript
    ;

  inherit (import ./_usersfun.nix {inherit pkgs lib;}) filterDarwinUserAttr;

  sopsInitSecrets = prefix: secretNames: lib.genAttrs (map (n: "${prefix}/${n}") secretNames) (a: {});

  sopsInitSecretsPerms = prefix: owner: group: mode: secretNames:
    lib.genAttrs (map (n: "${prefix}/${n}") secretNames) (a: {
      inherit owner group mode;
    });

  sopsCatSecretCmd = cfg: relpath: "cat /run/secrets/${cfg.sops.secrets.${relpath}.name}";

  matchFileFromRegEx = dir: repat:
    builtins.head ((lst:
      if builtins.length lst < 1
      then
        throw
        ''FATAL: no file found in "${dir}" matching regex pattern "${repat}"''
      else lst) (builtins.filter (f: builtins.match repat f != null)
      (builtins.attrNames (builtins.readDir dir))));

  # TODO: still useful/needed? What about systemd tempfile?
  ensureDirScript = {
    dir,
    owner ? "",
    mode ? "",
  }:
    pkgs.writeScript "ensuredir.sh" ''
      #!${pkgs.bash}/bin/bash
                  [[ -d "${dir}" ]] || mkdir -p "${dir}"
                  [[ -n "${owner}" ]] && chown ${owner} "${dir}"
                  [[ -n "${mode}" ]] && chmod ${mode} "${dir}"
                  exit 0
    '';

  fromYAML = yaml:
    builtins.fromJSON (builtins.readFile (pkgs.stdenv.mkDerivation {
      name = "fromYAML";
      phases = ["buildPhase"];
      buildPhase = "${pkgs.yaml2json}/bin/yaml2json < ${
        builtins.toFile "yaml" yaml
      } > $out";
    }));

  # user: argument is a config.users.users.<name> attribute set!
  # to auto-generate ssh keypairs (passwordless -> restricted!) for use in e.g. backup jobs
  ensureSSHKeysScript = user: keyBaseName: let
    sshdir = "${user.home}/.ssh";
  in {
    script.text = ''
      #!${pkgs.runtimeShell}

      ls "${sshdir}" 2>/dev/null || {
        mkdir ${sshdir}
        chmod 700 ${sshdir}
        chown ${user.name}:${user.group} ${sshdir}
      }

      ls "${sshdir}/${keyBaseName}" 2>/dev/null || {
        ${pkgs.openssh}/bin/ssh-keygen -N "" -o -a256 -b 4096 -t ed25519 -C "${user.name}@$(hostname)-$(date +'%Y-%m-%d')" -f ${sshdir}/${keyBaseName}
        chown ${user.name}:${user.group} ${sshdir}/${keyBaseName}*
      }
    '';
  };

  mkWireguardConfigs = wgcfgs: let
    mkNetDevCfg = {
      ifname,
      MTU ? "1412",
      pkFile,
      pskFile,
      peers,
      listenPort ? "auto",
      ...
    }: {
      netdevConfig = {
        Kind = "wireguard";
        Name = ifname;
        MTUBytes = MTU;
        # https://schroederdennis.de/vpn/wireguard-mtu-size-1420-1412-best-practices-ipv4-ipv6-mtu-berechnen/
        # https://serverfault.com/a/1040176/600083
      };
      wireguardConfig = {
        ListenPort = listenPort;
        PrivateKeyFile = pkFile;
      };
      # if a peer has THIS host as an endpoint, only two fields should be given: allowedIPs with the peer's WG IP and the PublicKey.
      # For convenience the psk is taken the same for the whole interface/subnet
      wireguardPeers = map (p:
        {
          PresharedKeyFile = pskFile;
        }
        // p)
      peers;
    };

    mkNetworkCfg = {
      ifname,
      ifAddr ? [],
      routeIPs ? [],
      dns ? [],
      domains ? [],
      networkConfig ? {},
      linkConfig ? {},
      ...
    }: {
      matchConfig.Name = "${ifname}";
      address = ifAddr;
      # https://gist.github.com/brasey/fa2277a6d7242cdf4e4b7c720d42b567?permalink_comment_id=4002831#gistcomment-4002831
      inherit dns domains;
      routes = map (r: {Destination = r;}) routeIPs;
      inherit networkConfig;
      inherit linkConfig;
    };
  in {
    enable = true;
    netdevs = lib.foldr (a: b: a // b) {} (
      map
      (
        c:
          lib.genAttrs [
            "${
              if builtins.hasAttr "prio" c
              then toString c.prio
              else "10"
            }-${c.ifname}"
          ] (
            _: (mkNetDevCfg c)
          )
      )
      wgcfgs
    );
    networks = lib.foldr (a: b: a // b) {} (
      map (c: lib.genAttrs ["${c.ifname}"] (_: (mkNetworkCfg c))) wgcfgs
    );
  };
}
