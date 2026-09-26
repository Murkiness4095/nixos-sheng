# ---
# Module: sheng-local entry
# Description: Aggregates this branch's local platform patches so upstream-owned files stay untouched
# Scope: System
# Notes:
# - 本目录只放"上游 sheng 没有、但本分支需要"的平台改动。桌面相关配置放
#   profiles/ 与 packages/，不要放这里。
# - 不要为了让功能生效去改上游文件（configuration.nix、hardware/*.nix 等）。
#   上游文件保持原样，合并上游时就不会冲突。规则见
#   docs/branch-and-merge-rules_zh.md。
# - 每个文件都要写清楚：为什么需要、上游缺什么、什么时候可以删。
# ---
{
  imports = [
    ./wifi.nix
    ./pd-maps.nix
    ./display-manager-vt.nix
    ./user-session.nix
    ./touch.nix
    ./sensors.nix
  ];
}
