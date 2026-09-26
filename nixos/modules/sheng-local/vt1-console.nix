# ---
# Module: sheng-local VT1 console
# Description: Let fbcon render VT1 so text greeters and console logins are visible
# Scope: System
# Notes:
# - 上游 sheng-boot-animation.nix 把 fbcon 限制在 VT3-6（`fbcon=vc:3-6`），VT1 留给
#   显示管理器、VT2 留给启动动画。GDM/niri 这类直接走 DRM 画图的管理器没问题，
#   但 greetd 的文本 greeter（tuigreet）是把 TUI 写到 /dev/tty1 的：VT1 没有 fbcon
#   绑定，写进去的内容永远不会渲染，屏幕上留着启动动画的最后一帧。
# - 现象：看不到登录界面（"卡在 NixOS logo"），`cat /dev/vcs1` 却能看到 tuigreet
#   的界面文本；niri 会话能起来，只是屏幕上什么都看不到。
# - fbcon 的 `vc:` 参数按 cmdline 顺序解析、后写覆盖，这里用 mkAfter 保证 vc:1-6
#   排在上游那条之后。VT2 由启动动画以 KD_GRAPHICS 压住，内核 console 仍在 tty3；
#   对 GDM 这条线没有影响（GDM 不往 VT1 的 console 写），对无显示管理器的 minimal
#   只是让 VT1 也能显示文本。
# - 设备侧曾出现"刷完 boot_b 卡在启动界面"，随后确认**去掉本参数的同版本镜像同样卡**
#   （用户实测），所以那与本参数无关，另行排查（需要 stage-1 的 /run/log/stage-1.log）。
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
