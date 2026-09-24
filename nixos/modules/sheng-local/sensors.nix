# ---
# Module: sheng-local sensor compat paths
# Description: Exposes the Android sensor config path to sheng-devauth the same way adsprpcd sees it
# Scope: System
# Notes:
# - devauth 可能通过 Android 兼容路径读取传感器/注册表数据，adsprpcd 已经用
#   BindReadOnlyPaths 映射了同一份目录，这里给 devauth 补上。
# - 上游 xiaomi-sheng/sensors/default.nix 没有这一条，因此放在本目录而不是改上游文件。
# ---
{ lib, ... }:

{
  systemd.services.sheng-devauth.serviceConfig.BindReadOnlyPaths =
    lib.mkAfter [ "/etc/sensors/config:/odm/etc/sensors/config" ];
}
