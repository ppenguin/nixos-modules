{
  description = "NixOS and Home-Manager modules";

  outputs = { self, nixpkgs }: {

    nixosModules = {
      gddnsup = import ./nixos/gddnsup self;
    };

    homeManagerModules = {
      iiorient = import ./home-manager/iiorient self;
    };

  };
}
