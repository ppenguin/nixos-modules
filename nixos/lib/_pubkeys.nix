# Pure utility — only builtins, no nixpkgs required.
# Works identically in NixOS and HM module bodies.
#
# pubkeysFromDir dir          → all *.pub files from dir as key strings
# filterPubkeys patterns keys → keep only keys whose name field matches any pattern (ERE)
#
# Example:
#   let pk = import ../../lib/pubkeys.nix;
#   in pk.filterPubkeys [".*@gtnet" ".*borg.*"] (pk.pubkeysFromDir ./users/theman/_pubkeys)
{
  # Returns all *.pub files from `dir` as a list of key strings.
  pubkeysFromDir = dir:
    builtins.readDir dir
    |> builtins.attrNames
    |> builtins.filter (f: builtins.match ".*\\.pub" f != null)
    |> map (f: builtins.readFile (dir + "/${f}"))
    |> map (builtins.replaceStrings ["\n" "\r"] ["" ""]);

  # Filters a key list, keeping only keys whose name field matches at least one ERE pattern.
  filterPubkeys = patterns: keys:
    keys
    |> builtins.filter (key:
      builtins.any (p:
        builtins.match p
        (builtins.elemAt
          (builtins.filter builtins.isString (builtins.split " " key))
          2)
        != null)
      patterns);
}
