{
  pkgs,
  lib,
  ...
}: {
  sopsInitSecrets = prefix: secretNames: lib.genAttrs (map (n: "${prefix}/${n}") secretNames) (a: {});

  sopsCatHMSecretCmd = hmcfg: relpath: "${pkgs.coreutils}/bin/cat ${hmcfg.xdg.configHome}/sops-nix/secrets/${hmcfg.sops.secrets."${relpath}".name}";
}
