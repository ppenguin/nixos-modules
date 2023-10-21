{
  description = "NixOS and Home-Manager modules";

  outputs = { self }: {

    nixosModules = {
      compose-pod = import ./nixos/compose-pod self;
      gddnsup = import ./nixos/gddnsup self;
      go-shadowsocks2 = import ./nixos/go-shadowsocks2 self;
      linger = import ./nixos/linger self;
      powerdns = import ./nixos/powerdns self;
    };

    homeManagerModules = {
      hyprpaper = import ./home-manager/hyprpaper self;
      iiorient = import ./home-manager/iiorient self;
      monitors = import ./home-manager/monitors self;
      stylish = import ./home-manager/stylish self;
    };

  };
}
