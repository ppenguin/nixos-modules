{
  python3,
  stdenv,
  lib
}:
stdenv.mkDerivation {
  pname = "rpi4-pwmfan";
  version = "0.1.0";

  propagatedBuildInputs = [ 
    (python3.withPackages (p: with p; [ rpi-gpio ]))
  ];

  dontUnpack = true;

  installPhase = "install -Dm755 ${./rpi4-pwmfan.py} $out/bin/rpi4-pwmfan.py"; 

  meta = with lib; {
    description = "A simple PWM fan control daemon for Raspberry Pi4";
    license = licenses.mit;
    maintainers = with maintainers; [ppenguin];
    platforms = platforms.linux;
  };
}
