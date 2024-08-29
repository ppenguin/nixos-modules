{
  lib,
  stdenvNoCC,
  fetchurl,
  variant ? "Modern-Classic",
}: let
  hcversion = "1.0";

  variants = {
    Modern-Classic = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Modern-Classic.tar.gz";
      name = "hypr_Bibata-Modern-Classic.tar.gz";
      sha256 = "sha256-+ZXnbI3bBLcb0nv2YW3eM/tK4dsraNM4UAO9BpSqfXk=";
    };
    Modern-Amber = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Modern-Amber.tar.gz";
      name = "hypr_Bibata-Modern-Amber.tar.gz";
      sha256 = "0zd56v9v8kfvslv2836jig51lvkz3vw6amv07ahy5g0akxpw0mh5";
    };
    Modern-Ice = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Modern-Ice.tar.gz";
      name = "hypr_Bibata-Modern-Ice.tar.gz";
      sha256 = "1y1c3mll5bx2qnv8xqam4vk6x1saxh56v248pknk7xgbg7l4dnyy";
    };
    Original-Classic = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Original-Classic.tar.gz";
      name = "hypr_Bibata-Original-Classic.tar.gz";
      sha256 = "1f3bv50hx83swzv4kjhp42r6173dnh4cf2djn7zygxn8hhjr336b";
    };
    Original-Amber = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Original-Amber.tar.gz";
      name = "hypr_Bibata-Original-Amber.tar.gz";
      sha256 = "sha256-WTXiuRje6VJlVDayvI9GzvKYNjdgXYqKRi8t2QRanDk=";
    };
    Original-Ice = {
      url = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/${hcversion}/hypr_Bibata-Original-Ice.tar.gz";
      name = "hypr_Bibata-Original-Ice.tar.gz";
      sha256 = "1nz2dk2cafnxdhpcrbg1g046pwb999f9gmm0axljk1pqvbp1cvi7";
    };
  };
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bibata-hyprcursor";

    # inherit (bibata-cursors) version;
    version = hcversion;

    src = fetchurl {inherit (variants.${variant}) url name sha256;};

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/icons/BibataHypr-${variant}
      cp -r /build/manifest.hl /build/hyprcursors $out/share/icons/BibataHypr-${variant}/

      runHook postInstall
    '';

    meta = {
      description = "Open source, compact, and material designed cursor set";
      homepage = "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
      maintainers = with lib.maintainers; [fufexan];
    };
  })
