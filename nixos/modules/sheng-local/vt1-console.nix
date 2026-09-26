# ---
# Module: sheng-local VT1 console
# Description: Let fbcon render VT1 so text greeters and console logins are visible
# Scope: System
# Notes:
# - 上游 sheng-boot-animation.nix 把 fbcon 限制在 VT3-6（`fbcon=vc:3-6`），VT1 留给
#   显示管理器、VT2 留给启动动画。这对 GDM/niri 这种直接走 DRM 画图的管理器没问题，
#   但 greetd 的文本 greeter（tuigreet）是把 TUI 写到 /dev/tty1 的：VT1 没有 fbcon
#   绑定，写入的内容永远不会被渲染，面板上留着的是启动动画的最后一帧。
# - 现象：reboot 后“卡在 NixOS logo 不动”，其实 tuigreet 正在跑（`cat /dev/vcs1`
#   能看到它的界面文本）、niri 会话也能起来，只是屏幕上什么都看不到；VT3-6 又没人切过去，
#   所以连“tty 也没弹出来”。
# - fbcon 的 `vc:` 参数按 cmdline 顺序解析、后写覆盖，这里用 mkAfter 保证我们的
#   `vc:1-6` 排在上游那一条之后。VT2 由启动动画用 KD_GRAPHICS 压住，不受影响；
#   内核 console 仍在 tty3。
# - 上游若把 VT1 一并纳入 fbcon，本文件可删。
# - 合并上游后如果这条不再排在最后（求值会直接失败），说明上游改了 cmdline 组装方式，
#   需要重新确认 `cat /proc/cmdline | tr ' ' '\n' | grep fbcon` 的末项仍是 vc:1-6。
# ---
{ config, lib, ... }:

let
  fbconParams = builtins.filter (p: lib.hasPrefix "fbcon=" p) config.boot.kernelParams;
in
{
  boot.kernelParams = lib.mkAfter [ "fbcon=vc:1-6" ];

  assertions = [
    {
      assertion = fbconParams != [ ] && lib.last fbconParams == "fbcon=vc:1-6";
      message = ''
        sheng-local/vt1-console.nix: 期望 fbcon=vc:1-6 是 cmdline 里最后一条 fbcon 参数，
        实际为: ${lib.concatStringsSep " " fbconParams}
        上游若改动了 sheng-boot-animation.nix 的 cmdline 组装，请同步本模块。
      '';
    }
  ];
}
