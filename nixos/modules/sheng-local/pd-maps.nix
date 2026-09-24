# ---
# Module: sheng-local pd-mapper firmware
# Description: Keeps vendor PD map files uncompressed inside hardware.firmware so pd-mapper can enumerate them
# Scope: System
# Notes:
# - pd-mapper 只在 firmware 目录里枚举 *.jsn / *.jsn.xz。NixOS 会把
#   /sys/module/firmware_class/parameters/path 指向 hardware.firmware 聚合目录，
#   而 nixpkgs 默认把固件统一压缩成 .zst，厂商的明文 adspr.jsn 于是匹配不上 →
#   "no pd maps available" → exit 1 → Restart=on-failure 每 5 秒重启一次，并通过
#   Requires= 连带重启 sheng-devauth，键盘认证被反复打断。
# - 这里把厂商固件里原本就是明文的 .jsn 再放一份进 hardware.firmware，并用
#   compressFirmware = false（nixpkgs 官方的压缩豁免开关）保持明文。
# - 纯声明式，不修改 pd-mapper 二进制，也不需要运行时脚本。
# ---
{ lib, pkgs, ... }:

let
  pdMapsPlain = pkgs.runCommand "sheng-pd-maps-plain" {
    compressFirmware = false;
  } ''
    mkdir -p "$out/lib/firmware/qcom/sm8550/sheng"
    cp ${pkgs.sheng-firmware}/lib/firmware/qcom/sm8550/sheng/*.jsn \
      "$out/lib/firmware/qcom/sm8550/sheng/"
  '';
in
{
  hardware.firmware = lib.mkAfter [ pdMapsPlain ];
}
