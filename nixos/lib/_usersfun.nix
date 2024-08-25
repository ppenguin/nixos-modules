{
  pkgs,
  lib,
}: let
  inherit (pkgs) system;

  notDarwinUserAttr = [
    "uid"
    "groups"
    "isNormalUser"
    "openssh"
    "defaultUserShell"
    "extraGroups"
    "subUidRanges"
    "subGidRanges"
  ];

  # Function to generate a list of subID ranges for a user
  generateSubIdRanges = {
    startId,
    count,
  }: [
    {
      startUid = startId;
      inherit count;
    }
    {
      startGid = startId;
      inherit count;
    }
  ];
in {
  filterDarwinUserAttr = attrset:
    if lib.hasInfix "darwin" system
    then lib.attrsets.filterAttrsRecursive (n: v: !(builtins.any (a: a == n) notDarwinUserAttr)) attrset
    else attrset; # return unfiltered if not darwin

  # Function to merge subIDs for a list of users
  # mergeSubIds = { users, usernames, subIdStart }:
  #   let
  #     # Initialize variables to track UID and GID ranges
  #     mutable currentUid = subIdStart;
  #     mutable currentGid = subIdStart;
  #   in
  #   lib.foldl' (username: user: acc:
  #     let
  #       subIdRanges = generateSubIdRanges { startId = currentUid; count = 65535; };
  #       currentUid = currentUid + 65536; # Increment for the next user
  #       currentGid = currentGid + 65536;
  #     in
  #     getAttr user.name
  #     lib.attrsets.update(user, {
  #       subUidRanges = subIdRanges;
  #       subGidRanges = subIdRanges;
  #     }) acc
  #   ) users usernames;
}
