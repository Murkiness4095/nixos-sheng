# Upstream iio-sensor-proxy, patched to speak to Qualcomm's SSC sensor
# stack via libssc (accelerometer/proximity/light/compass over QRTR).
# Base: https://gitlab.freedesktop.org/hadess/iio-sensor-proxy (3.9)
# Patches: postmarketOS pmaports !7091 (device/testing/sheng-iio-sensor-proxy)
{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  glib,
  libgudev,
  udev,
  polkit,
  libssc,
}:

stdenv.mkDerivation {
  pname = "sheng-iio-sensor-proxy";
  version = "3.9";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "hadess";
    repo = "iio-sensor-proxy";
    rev = "3.9";
    hash = "sha256-2N/4Fp6QtAhgEzX9cHEDJhFtRsyrtZ80I2jdHdeEmxA=";
  };

  # SSC support and client/driver lifetime fixes are upstream in 3.9.
  patches = [ ./0104-sheng-discovery-3.9.patch ];

  # meson.build takes polkit's policydir from pkg-config with no override, so
  # it lands outside $out.
  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail \
      "polkit_policy_directory = polkit_gobject_dep.get_pkgconfig_variable('policydir')" \
      "polkit_policy_directory = get_option('prefix') / 'share' / 'polkit-1' / 'actions'"
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [
    glib
    libgudev
    udev
    polkit
    libssc
  ];

  mesonFlags = [
    "-Dssc-support=enabled"
    "-Dsystemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
    "-Dudevrulesdir=${placeholder "out"}/lib/udev/rules.d"
  ];

  postInstall = ''
    install -Dm644 ${./10-sheng-sensors.conf} \
      "$out/lib/systemd/system/iio-sensor-proxy.service.d/10-sheng-sensors.conf"
  '';

  meta = {
    description = "IIO sensor to input proxy, with Qualcomm SSC sensor support for sheng";
    license = lib.licenses.gpl3Only;
    platforms = [ "aarch64-linux" ];
  };
}
