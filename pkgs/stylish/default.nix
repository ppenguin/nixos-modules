{
  lib,
  fetchFromGitHub,
  curl,
  file,
  gawk,
  imagemagick,
  jq,
  libnotify,
  util-linux,
  writeShellApplication,
  # feature flags
  withX ? false,
  withPlugins ? true,
}:
with builtins;
let
  inherit (lib) optionals;
  inherit (lib.strings) splitString concatStringsSep;
  inherit (lib.lists) drop;

  # src = ./src;
  src = fetchFromGitHub {
    owner = "ppenguin";
    repo = "styli.sh";
    rev = "improve+imagemagick-7";
    hash = "sha256-JscUjjrufmg8JEDnG/pCpPhLT5StwBXImsroNFYo7Vk=";
  };

  mainscript = replaceStrings [ "$THIS/plugins" ] [ "${src}/plugins" ] (
    concatStringsSep "\n" (drop 1 (splitString "\n" (readFile "${src}/styli.sh")))
  );
in
writeShellApplication {
  name = "styli.sh";
  runtimeInputs =
    [
      curl
      file
      jq
      util-linux
      gawk
    ]
    ++ optionals withX [ feh ]
    ++ optionals withPlugins [
      libnotify
      imagemagick
    ];

  text = mainscript;
}
