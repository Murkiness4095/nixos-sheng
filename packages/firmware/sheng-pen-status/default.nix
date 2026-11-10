# Qt tray utility + CLI showing Focus Pen stylus battery/pairing status via
# qcom_battmgr sysfs, auto-pairs the stylus over BlueZ.
# Source: https://github.com/ianchb/xiaomi-pen-status
{ lib, stdenv, fetchFromGitHub, fetchurl, qt6, pkg-config }:

let
  # Upstream removed the standalone CLI from the current GUI tree. Keep the
  # existing command available while updating the GUI and pen support.
  cliSrc = fetchurl {
    url = "https://raw.githubusercontent.com/ianchb/xiaomi-pen-status/8b0ff3eb143b84541cc1e55ea9cdd3a723256021/xiaomi-pen-status-cli.cpp";
    hash = "sha256-zFPlpKdObUruxYDGWoGAb0n/4qL/SFn/bwrczrQ+nZA=";
  };
in
stdenv.mkDerivation {
  pname = "sheng-pen-status";
  version = "0.2.3";

  src = fetchFromGitHub {
    owner = "ianchb";
    repo = "xiaomi-pen-status";
    rev = "fcf349109d2e69aedf7170479cc38b102ba1d4c0";
    hash = "sha256-UwRYo4nSElw14HRsuNlR7XimSA26RLmsB4iivf9IT6Y=";
  };

  nativeBuildInputs = [ qt6.qmake qt6.wrapQtAppsHook pkg-config ];
  buildInputs = [ qt6.qtbase qt6.qtsvg ];

  # Upstream guards a single system-wide instance with a fixed /tmp lock and an
  # unqualified abstract socket. On a multi-user machine the second user's
  # launch silently exits. Scope both to the user: uid in the socket name and
  # the lock under XDG_RUNTIME_DIR.
  postPatch = ''
    substituteInPlace main.cpp \
      --replace-fail '#include <QFile>' '#include <QFile>
#include <unistd.h>' \
      --replace-fail 'const QString serverName = QStringLiteral("xiaomi-pen-status");' \
        'const QString serverName = QStringLiteral("xiaomi-pen-status-") + QString::number(static_cast<qulonglong>(::getuid()));' \
      --replace-fail 'QLockFile lockFile(QDir::temp().absoluteFilePath(QStringLiteral("xiaomi-pen-status.lock")));' \
        'const QString lockDir = qEnvironmentVariable("XDG_RUNTIME_DIR", QDir::tempPath());
	QLockFile lockFile(QDir(lockDir).absoluteFilePath(QStringLiteral("xiaomi-pen-status.lock")));'
  '';

  buildPhase = ''
    runHook preBuild

    qmake6 xiaomi-pen-status.pro
    make

    $CXX -std=c++17 -O2 -Wall -Wextra -pedantic \
      ${cliSrc} -o xiaomi-pen-status-cli

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 xiaomi-pen-status "$out/bin/xiaomi-pen-status"
    install -Dm755 xiaomi-pen-status-cli "$out/bin/xiaomi-pen-status-cli"
    install -Dm644 xiaomi-pen-status.desktop \
      "$out/share/applications/xiaomi-pen-status.desktop"
    install -Dm644 xiaomi-pen-status.svg \
      "$out/share/icons/hicolor/scalable/apps/xiaomi-pen-status.svg"

    mkdir -p "$out/etc/xdg/autostart"
    sed 's/^Exec=.*/Exec=xiaomi-pen-status/' xiaomi-pen-status.desktop \
      > "$out/etc/xdg/autostart/xiaomi-pen-status.desktop"

    runHook postInstall
  '';

  meta = {
    description = "Stylus status tray/CLI for the Xiaomi Focus Pen (sheng)";
    license = lib.licenses.gpl2Only; # upstream ships a bare GPLv2 text, no "or later" grant
    platforms = [ "aarch64-linux" ];
    mainProgram = "xiaomi-pen-status";
  };
}
