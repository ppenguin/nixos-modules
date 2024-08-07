{
  description = "NixOS and Home-Manager modules";

  # TODO (maybe): play with https://gitlab.com/rycee/nmd to get a good look at modules documentation

  outputs = {self}: {
    nixosModules = {
      compose-pod = import ./nixos/compose-pod self;
      gddnsup = import ./nixos/gddnsup self;
      go-shadowsocks2 = import ./nixos/go-shadowsocks2 self;
      linger = import ./nixos/linger self;
      powerdns = import ./nixos/powerdns self;
    };

    homeManagerModules = {
      swaync = import ./home-manager/programs/swaync.nix self;
      hyprpaper = import ./home-manager/services/hyprpaper self;
      iiorient = import ./home-manager/services/iiorient self;
      monitors = import ./home-manager/config/monitors self;
      stylish = import ./home-manager/services/stylish self;
    };
  };
}
