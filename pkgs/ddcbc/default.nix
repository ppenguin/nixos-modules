{ writeShellApplication, ddcutil, gawk, ... }:
writeShellApplication {
  name = "ddcbc";
  runtimeInputs = [ ddcutil gawk ];
  text = builtins.readFile ./ddcbc.sh;
}
