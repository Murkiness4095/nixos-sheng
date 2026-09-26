# ---
# Module: sheng-local display manager VT guard
# Description: Keeps kmscon from owning the VTs whenever a display manager is enabled
# Scope: System
# Notes:
# - 上游的启动/充电界面模块（nixos/modules/sheng-boot-animation.nix，属上游，本分支
#   不改）把内核 console 钉到 tty3（`console=tty3` + `fbcon=vc:3-6`），tty1 留给
#   display manager、tty2 留给启动动画，并且只关掉 tty1/tty2 上的 getty@ 与 kmsconvt@。
# - 但 kmscon 只要开着，nixpkgs 的 kmscon 模块就会 `suppressedSystemUnits = [
#   "getty@.service" ]` 并把 `autovt@.service` 别名到 `kmsconvt@`：logind 在 VT 切换时
#   拉起的每个 VT（包括 tty3-6）跑的都是 kmscon。按实例名 `systemd.services."kmsconvt@ttyN".enable
#   = false` 只影响装机软链，拦不住 logind 的实例化。
# - 后果：greeter 想用的 VT1 拿不到显示，开机停在 tty3 的 kmscon 文本控制台，
#   从那里也起不了 Wayland 会话（DRM master 被 kmscon 占着）。
# - 上游的 gnome/niri profile 各自用 `services.kmscon.enable = lib.mkForce false`
#   兜住了自己那条线，但桌面中立的 `mkShengSystem`（下游 host 用的入口）不带 profile，
#   所以必须在这一层兜。只在有 display manager 时关：纯控制台镜像保留 kmscon 的
#   大字号终端（这块 12.4" 3K 屏上 fbcon 的 16px 字体基本没法看）。
# - 上游若把 kmscon 与 DM 的 VT 归属处理进 boot-animation 模块，本文件可删。
# ---
{ config, lib, ... }:

{
  services.kmscon.enable = lib.mkIf config.services.displayManager.enable (lib.mkForce false);
}
