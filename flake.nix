{
  description = "NixOS and Home-Manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  # TODO (maybe): play with https://gitlab.com/rycee/nmd to get a good look at modules documentation

  outputs = {self, ...} @ inputs: let
    pkgsSupportedSystems = ["x86_64-linux"];

    pkgsForSystem = system: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
    in
      builtins.mapAttrs (n: _: pkgs.callPackage ./pkgs/${n} {}) (lib.filterAttrs (_: v: v == "directory") (builtins.readDir ./pkgs));

    pkgsForSupportedSystems = let inherit (inputs.nixpkgs) lib; in lib.genAttrs pkgsSupportedSystems pkgsForSystem;
  in {
    nixosModules = {
      compose-pod = import ./nixos/modules/compose-pod self;
      gddnsup = import ./nixos/modules/gddnsup self;
      go-shadowsocks2 = import ./nixos/modules/go-shadowsocks2 self;
      linger = import ./nixos/modules/linger self;
      powerdns = import ./nixos/modules/powerdns self;
      wg-refresh = import ./nixos/modules/wg-refresh;
    };

    homeManagerModules = {
      swaync = import ./home-manager/modules/programs/swaync.nix self;
      hyprpaper = import ./home-manager/modules/services/hyprpaper self;
      iiorient = import ./home-manager/modules/services/iiorient self;
      monitors = import ./home-manager/modules/config/monitors self;
      stylish = import ./home-manager/modules/services/stylish self;
    };

    nixos-utils = ./nixos/lib/utils.nix;
    hm-utils = ./home-manager/lib/utils.nix;

    packages = pkgsForSupportedSystems; # TODO: (interesting): we could also expose the packages by exposing "overlayed" nixpkgs, but the difference is this would mean an additional nixpkgs instance, so it's in fact not the same?
    pkgsoverlay = import ./overlays/pkgs.nix;
  };
}
