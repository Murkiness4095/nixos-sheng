# ---
# Module: sheng-local boot UI session guard
# Description: Stop the boot UI from taking the display over once a display manager owns it
# Scope: System
# Notes:
# - 上游 sheng-boot-animation.nix 只靠 /run/sheng-boot-ui.done 阻止开机动画在 boot 之后
#   重播，而这个标记由 display-manager.service 的 preStart 写。greetd 镜像里
#   display-manager.service 只是 greetd.service 的别名，钩子会被丢弃（见
#   greeter-boot-ui-handoff.nix）；标记缺失时 `nixos-rebuild switch` 重新拉起
#   graphical.target 的依赖会把动画又拉起来：painter 抢 VT2 + KD_GRAPHICS，
#   120 秒后落 VT3；compositor 占着 CRTC 时 fbcon 画不出来
#   （`fb0: sys_imageblit: framebuffer is not in virtual address space`），
#   屏幕就停在最后一帧雪花上，而系统本身（SSH、niri）一直活着。
# - 这里加两层与 DM 名称无关的兜底：
#   1. display-manager.service 已经 active 时用 ExecCondition 跳过启动动画；
#      ExecCondition 以 1..254 退出只跳过、不算失败（systemd.service(5) v243+）。
#   2. 诊断回退在有会话时先停动画并把 VT 交回显示管理器，而不是切到画不出来的 VT3。
# - 上游若自己按 displayManager 名称判断，本文件可删。
# ---
{ config, lib, pkgs, ... }:

let
  control = "/run/sheng-boot-ui";
  painter = "${pkgs.sheng-fb-painter}/bin/sheng-fb-painter";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  # VT1 belongs to the display manager; VT2 is the boot UI, VT3-6 the text consoles.
  displayManagerVt = "1";
in
{
  systemd.services.sheng-boot-splash.serviceConfig.ExecCondition =
    pkgs.writeShellScript "sheng-boot-splash-session-guard" ''
      # Skip the boot UI whenever a display manager already owns the display.
      if ${systemctl} is-active --quiet display-manager.service; then
        exit 1
      fi
      exit 0
    '';

  systemd.services.sheng-boot-details.serviceConfig.ExecStart = lib.mkForce (
    pkgs.writeShellScript "sheng-boot-details-session-aware" ''
      # A running display manager means the session's VT is the only surface that can
      # still be drawn to; VT3 would stay invisible behind the compositor's CRTC.
      if ${systemctl} is-active --quiet display-manager.service; then
        ${pkgs.coreutils}/bin/touch ${control}.done
        ${painter} --stop ${control} || true
        exec ${pkgs.kbd}/bin/chvt ${displayManagerVt}
      fi
      exec ${painter} --details ${control}
    ''
  );
}
