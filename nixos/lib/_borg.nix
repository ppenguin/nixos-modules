{sopsCatSecretCmd}: {
  borgStandardJob = {
    user,
    repo,
    startAt ? "daily",
    paths,
    exclude,
    persistentTimer ? false,
  }: {
    # extraArgs = "--debug";
    startAt = startAt; # https://www.freedesktop.org/software/systemd/man/systemd.time.html
    user = user.name;
    inherit (user) group;
    inherit repo; # the correct repo is automatically selected by the unique public key of the local borgbackup user
    doInit = false;

    environment = {
      BORG_RSH = "ssh -i ${user.home}/.ssh/id_borgbackup";
      BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes"; # this appears also to be necessary if the repo is encrypted but accessed for the first time from a new host
    };

    encryption = {
      # FIXME: change to passfile and pass it in as a sops path???
      passCommand = sopsCatSecretCmd "borgbackup/repopasses/${user.name}";
      mode = "authenticated-blake2"; # "repokey-blake2";
    };

    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 4;
      monthly = -1; # Keep at least one archive for each month
    };

    inherit paths exclude;
  };
}
