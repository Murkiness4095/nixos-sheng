# ---
# Module: sheng-local greeter boot-UI handoff
# Description: Re-attach the Sheng boot animation handoff to greetd's real systemd unit
# Scope: System
# Notes:
# - 本 nixpkgs（modular services）的 greetd 模块把显示管理器定义成 `greetd.service`
#   （`aliases = [ "display-manager.service" ]`）。nixos/lib/systemd-lib.nix 生成
#   systemd/system 时先链接普通 unit、之后才执行 aliases 的 `ln -sfn`，所以
#   `display-manager.service` 最终是指向 `greetd.service` 的别名，同名 unit 被覆盖。
# - 上游 nixos/modules/sheng-boot-animation.nix 把「停 painter + 写 .done」的 preStart
#   和 onFailure 挂在 `systemd.services.display-manager` 上，于是这两项在 greetd 镜像里
#   被静默丢弃：显示管理器启动前不会停掉开机动画，DM 失败也不会切到诊断控制台，
#   屏幕停在动画最后一帧（VT1/VT2 没有 fbcon，没人重画）。GDM 自己定义
#   display-manager.service，没有别名覆盖，不受影响。
# - 验证：`ls -l /etc/systemd/system/display-manager.service` 应指向 greetd.service，
#   且 `systemctl cat greetd` 里必须出现 /run/sheng-boot-ui。
# - 上游若改成按 services.displayManager 的实际 unit 挂接，本文件可删。
# ---
{ config, lib, pkgs, ... }:

let
  control = "/run/sheng-boot-ui";
  painter = "${pkgs.sheng-fb-painter}/bin/sheng-fb-painter";
in
{
  systemd.services.greetd = lib.mkIf config.services.greetd.enable {
    # 与上游 display-manager 钩子保持同一行为。
    preStart = lib.mkBefore ''
      # Do not replay the boot UI when a later system switch restarts units.
      ${pkgs.coreutils}/bin/touch ${control}.done
      # Acknowledge the writer's exit before the compositor acquires scanout.
      ${painter} --stop ${control} || true
    '';
    onFailure = [ "sheng-boot-details.service" ];
  };
}
