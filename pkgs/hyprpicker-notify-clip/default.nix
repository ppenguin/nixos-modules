{
  hyprpicker,
  libnotify,
  wl-clipboard,
  writeShellApplication,
}:
writeShellApplication {
  name = "hyprpicker-notify-clip";
  runtimeInputs = [
    hyprpicker
    libnotify
    wl-clipboard
  ];
  text = ''
    notify-send "hyprpicker" "$(hyprpicker -n -a -f hex)"
  '';
}
