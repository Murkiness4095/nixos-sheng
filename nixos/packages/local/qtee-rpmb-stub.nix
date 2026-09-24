# ---
# Package: qtee-rpmb-listener-stub
# Description: No-op QTEE RPMB listener plugin that keeps qteesupplicant's dlopen contract without claiming service 0x2000
# Scope: Script
# Notes:
# - QTEE 的 RPMB listener（service ID 0x2000）是单占用的 TEE 服务，三个程序都想要
#   这个槽位：xiaomi-sheng-fingerprint 的 qteesupplicant（通过
#   lib/qtee-listeners/librpmbservice.so，开机就注册且不释放）、
#   libfpc1553-qtee.so（静态链了一份 librpmbservice）、以及 xiaomi_devauth
#   （键盘盖认证，按需注册后 deinit）。先注册者赢，后来的报
#   `IRegisterListenerCBO_register(8192) failed: 0xffffff9d`，devauth 视为致命
#   错误退出，于是键盘盖永远认证不上，nanosic WN8030 驱动每次认证都卡 5 秒。
# - 用 stub 顶掉 qteesupplicant 的插件：保留 init/deinit 符号，但不注册服务，
#   让临时使用者能拿到槽位。若指纹录入/验证回归，删掉 flake.nix 里的覆盖即可恢复。
# ---
{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "qtee-rpmb-listener-stub";
  version = "1.0.0";

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    cat > librpmbservice-stub.c <<'EOF'
    /* Stub replacement for librpmbservice.so. qteesupplicant dlopen()s this
       library and resolves init/deinit, but it must not register QTEE
       listener service 0x2000: xiaomi_devauth owns that slot. */
    int init(void) { return 0; }
    int deinit(void) { return 0; }
    EOF
    $CC -O2 -fPIC -shared -Wl,-soname,librpmbservice.so.1 \
      -o librpmbservice.so.1.0.0 librpmbservice-stub.c
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm0644 librpmbservice.so.1.0.0 \
      "$out/lib/librpmbservice.so.1.0.0"
    ln -s librpmbservice.so.1.0.0 "$out/lib/librpmbservice.so.1"
    runHook postInstall
  '';

  meta = {
    description = "No-op QTEE RPMB listener plugin for qteesupplicant";
    platforms = lib.platforms.linux;
  };
}
