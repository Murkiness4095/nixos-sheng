# Userspace client library for Qualcomm's Sensor Core (SSC) DSP stack --
# talks QMI/QRTR to the sensorspd daemon running on the aDSP.
# Source: https://codeberg.org/DylanVanAssche/libssc
{
  lib,
  stdenv,
  fetchFromGitea,
  fetchpatch,
  meson,
  ninja,
  pkg-config,
  glib,
  protobuf,
  protobufc,
  libqmi,
  python3,
}:

stdenv.mkDerivation {
  pname = "libssc";
  version = "0.4.4";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "DylanVanAssche";
    repo = "libssc";
    rev = "033e2a32095c024d6dbdfb1d4ae1db4a94be32f1";
    hash = "sha256-1ZgEUddT2VGaR+bQrSPNJehzmQMp7EuCQOoRr12B9+w=";
  };

  # Adds a 5x1s retry around the SSC service lookup: sensorspd takes a moment
  # to enumerate on QRTR after adsprpcd-sensorspd.service starts.
  patches = [
    (fetchpatch {
      url = "https://raw.githubusercontent.com/ianchb/debian-sheng/master/patches/wait_for_qmi_service.patch";
      hash = "sha256-Ee3Jq8ITM5WQebHaYWZeVTuPYBFu3uMbDIoSQ3Zb6Cg=";
    })
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    protobuf
    python3
  ];
  buildInputs = [ glib ];
  # libssc.pc Requires: these, so consumers resolving it via pkg-config need
  # them on their own PKG_CONFIG_PATH.
  propagatedBuildInputs = [
    protobufc
    libqmi
  ];

  meta = {
    description = "Client library for Qualcomm Sensor Core (SSC)";
    license = lib.licenses.gpl3Only; # upstream ships a bare GPLv3 text, no "or later" grant
    platforms = [ "aarch64-linux" ];
  };
}
