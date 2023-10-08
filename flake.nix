{
  description = "NixOS and Home-Manager modules";

  outputs = { self }: {

    nixosModules = {
      gddnsup = import ./nixos/gddnsup self;
      compose-pod = import ./nixos/compose-pod self;
      linger = import ./nixos/linger self;
    };

    homeManagerModules = {
      iiorient = import ./home-manager/iiorient self;
      hyprpaper = import ./home-manager/hyprpaper self;
      stylish = import ./home-manager/stylish self;
      monitors = import ./home-manager/monitors self;
    };

  };
}
