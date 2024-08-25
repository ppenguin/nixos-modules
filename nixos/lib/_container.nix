# Convenience functions to define containers directly in nixos-config
# for use of podman containers as system services.
# TODO: get rid of this, it's clunky and not well scalable, better stick to a choice between:
# 1. first class services as nixos-modules
# 2. standard distributed orchestration (k3s/k8s/nomad)
# 3. (optionally) use our thin compose-systemd wrapper (also not scalable, but quicker to adopt ad-hoc than (2))
{
  pkgs,
  lib,
  sopsCatSecretCmd,
}: {
  podmanSecretEnvSops = varname: sopskey: ''"$(${sopsCatSecretCmd sopskey})",type=env,target=${varname}'';

  # Initialise user + DB + grant user acces to DB
  # NOOP for existing entities
  mkDbInitScript = {
    name,
    template,
    env,
  }:
    (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [gettext postgresql_15];
      text = with lib;
        (strings.concatMapStringsSep "\n" (i: "${i}=${lib.getAttr i env}")
          (lib.attrNames env))
        + "\n"
        + "export "
        + (strings.concatStringsSep " " (lib.attrNames env))
        + "\n"
        + "envsubst < ${template} | psql -f -";
    })
    + "/bin/${name}";

  # Execute e.g. DB population script
  mkDbExecSQLScript = {
    name,
    sqlfile,
    env,
  }:
    (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [gettext postgresql_15];
      text = with lib;
        (strings.concatMapStringsSep "\n" (i: "${i}=${lib.getAttr i env}")
          (lib.attrNames env))
        + "\n"
        + "export "
        + (strings.concatStringsSep " " (lib.attrNames env))
        + "\n"
        + "psql -f ${sqlfile}";
    })
    + "/bin/${name}";

  # Execute e.g. DB population script as user (for peer based auth, we use env but translate to flags)
  mkDbUserExecSQLScript = {
    name,
    sqlfile,
    env,
  }:
    (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [gettext postgresql_15];
      text = with lib; ''
        psql --username="${env.PGUSER}" --dbname="${env.PGDATABASE}" -f "${sqlfile}"'';
    })
    + "/bin/${name}";

  # get newest container version with (example)
  # skopeo list-tags --tls-verify=false docker://localhost:15000/nodebb/nodebb | jq -r '.Tags[] | select(test(".*"))' | sort -Vr | head -n1
  # with virtualisation.containers.registries.insecure correctly set we can skip the --tls-verify flag
  mkPodmanImgPullLatestScript = dockerrepo: imgname: filter: let
    name = imgname + "-pullimg.sh";
  in
    (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [coreutils skopeo jq];
      text = ''
        TAGS="$(skopeo list-tags --tls-verify=false ${dockerrepo}/${imgname} | jq -r '.Tags[] | select(test("${filter}"))' | sort -Vr | head -n1)"
        podman pull --tls-verify=false "${dockerrepo}/${imgname}:$TAGS" && echo "$TAGS" > /var/cache/containers/${imgname}.tags
      '';
    })
    + "/bin/${name}";
}
