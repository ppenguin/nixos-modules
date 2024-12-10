{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  version = "1.2.7";
  pname = "seaweedfs-csi-driver";
in
  buildGoModule {
    inherit pname;
    inherit version;

    src = fetchFromGitHub {
      owner = "seaweedfs";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-rahLMjJ9/KBugCJGAwQ+PYEBtDbcuq67kfUvLILhz2E=";
    };

    vendorHash = "sha256-UK4dhmU3USXEhxBx2BrXkltk63dS7TbLOWhRK1iYGaQ=";

    meta = with lib; {
      description = "SeaweedFS CSI Driver";
      homepage = "https://github.com/seaweedfs/seaweedfs-csi-driver";
      license = licenses.asl20;
      maintainers = with maintainers; [ppenguin];
    };
  }
