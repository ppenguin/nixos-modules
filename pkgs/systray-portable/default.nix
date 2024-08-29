{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "systray-portable";
  version = "0.1.2";
  rev = "87ea531e253ffe632e14b14c1bf31e7df11cf7cd";

  src = fetchFromGitHub {
    owner = "wobsoriano";
    repo = pname;
    inherit rev;
    hash = "sha256-HM1vycDOmUA8hRNuER9ageXTmgQcckr0o5j0fTjEWTs=";
  };

  vendorSha256 = "sha256-kWkRScgTBuhYVtubRSmeURLusdmrqup9XH0hrzlvLG4=";
  # vendorHash = null;
  # deleteVendor = true;
  # buildFlags = "-mod=mod";

  # re date: https://github.com/NixOS/nixpkgs/pull/45997#issuecomment-418186178
  # > .. keep the derivation deterministic. Otherwise, we would have to rebuild it every time.
  ldflags = [
    "-X main.version=v${version}"
    "-X main.commit=${rev}"
    "-X main.date=nix-byrev"
    "-s"
    "-w"
  ];

  # nativeBuildInputs = [ pkg-config libappindicator-gtk3 ];
  # buildInputs = [ libappindicator-gtk3 ];

  doCheck = false; # Display required

  meta = with lib; {
    description = "A portable version of go systray, using stdin/stdout to communicate with other language.";
    homepage = "https://github.com/wobsoriano/systray-portable";
    maintainers = with maintainers; [ppenguin];
    license = licenses.mit;
  };
}
