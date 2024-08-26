{
  description = "NixOS and Home-Manager modules";

  # TODO (maybe): play with https://gitlab.com/rycee/nmd to get a good look at modules documentation

  outputs = {self}: {
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
  };
}
