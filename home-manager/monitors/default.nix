# Based on https://github.com/Misterio77/nix-config/blob/main/modules/home-manager/monitors.nix
self:
{ lib, ... }:

let
  inherit (lib) mkOption types;
  # cfg = config.monitors;

in
{
  options.monitors = with types; mkOption {
    type = attrsOf (submodule {
      options = {
        name = mkOption {
          type = str;
          example = "monitor1";
        };
        description = mkOption {
          type = nullOr str;
          default = null;
          example = "SDC 0x4142";
        };
        output = mkOption {
          type = str;
          example = "DP-1";
        };
        isSecondary = mkOption {
          type = bool;
          default = false;
        };
        width = mkOption {
          type = int;
          default = null;
          example = 1920;
        };
        height = mkOption {
          type = int;
          default = null;
          example = 1080;
        };
        position = mkOption {
          type = attrsOf (nullOr int); # TODO: better with submodule (to force "x" and "y" members) but somehow it didn't work...
          default = { x = null; y = null; };
        };
        refreshRate = mkOption {
          type = nullOr int;
          default = null;
          example = 60;
        };
        scale = mkOption {
          type = float;
          default = 1;
        };
        enabled = mkOption {
          type = bool;
          default = true;
        };
        # TODO: do we need transform too?
        workspaces = mkOption {
          type = listOf str;
          default = [ ];
        };
      };
    });
  };

  # "module" as placeholder for embedded functions
  options.hyprlandConfig = {
    monitorConfig = mkOption { };
    wsbind = mkOption { };
  };

  # Convert config.monitors into hyprland's format
  config.hyprlandConfig =
    let
      inherit (builtins) concatStringsSep map toString filter hasAttr;
      inherit (lib.attrsets) mapAttrsToList;

      ident = m: (
        if m.description != null then
          "desc:${m.description}"
        else
          m.output
      );

      res = m: (
        if m.width != null && m.height != null then
          "${toString m.width}x${toString m.height}"
          + (if m.refreshRate != null then "@${toString m.refreshRate}" else "")
        else
          "preferred"
      );

      pos = m: (
        if m.position.x != null && m.position.y != null then
          "${toString m.position.x}x${toString m.position.y}"
        else
          "auto"
      );

    in
    {

      monitorConfig = monitors:
        concatStringsSep "\n" (map
          (m:
            ''monitor=${ident m}, ${res m}, ${pos m}, ${toString m.scale}''
          )
          (mapAttrsToList (_: v: v) monitors));

      wsbind = monitors:
        concatStringsSep "\n" (lib.flatten (map
          (m:
            (map (w: "workspace=${toString w},monitor:${m.output}") m.workspaces)
          )
          (filter (m: m.output != "") (mapAttrsToList (_: v: v) monitors))));
    };
}
