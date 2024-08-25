{
  config,
  pkgs,
  ...
}: {
  sopsCatHMSecretCmd = relpath: "${pkgs.coreutils}/bin/cat ${config.xdg.configHome}/sops-nix/secrets/${config.sops.secrets."${relpath}".name}";
}
