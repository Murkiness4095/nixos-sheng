# ---
# Module: sheng-local user session
# Description: Adds the session-level conveniences this branch needs (XDG dirs, journald limits, debugging packages, device udev rules)
# Scope: System
# Notes:
# - 全部是对上游文件的"追加"，不修改上游已有定义：
#   * XDG 用户目录：NixOS 默认不创建，GNOME 靠 xdg-user-dirs 的 autostart，
#     niri 这类不处理 autostart 的会话永远不会创建，家目录一直是空的。
#   * journald：上游仍用已废弃的 extraConfig（新 nixpkgs 会断言），这里清空并
#     改用 settings.Journal。
#   * evtest/iw：触摸、无线 bring-up 的诊断工具。
#   * udev 规则：键盘盖 HID 端点的 USB autosuspend、键盘盖重新对接后重跑
#     devauth、背光 sysfs 的 video 组写权限（Noctalia/brightnessctl 需要）。
# ---
{ config, lib, pkgs, ... }:

{
  # 刷入后启动即可见的标准 XDG 用户目录：Desktop、Documents、Downloads、Music、
  # Pictures、Public、Templates、Videos、Projects。幂等，只补缺失项，同时写出
  # ~/.config/user-dirs.dirs。LANG 固定 C.UTF-8，避免 zh_CN 环境下生成中文目录名。
  systemd.services.xdg-user-dirs = {
    description = "Create XDG user directories for normal users";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for home in /home/*; do
        [ -d "$home" ] || continue
        owner="$(${pkgs.coreutils}/bin/stat -c %U "$home")" || continue
        [ "$owner" = root ] && continue
        ${lib.getExe' pkgs.util-linux "runuser"} -u "$owner" -- \
          ${pkgs.coreutils}/bin/env HOME="$home" LANG=C.UTF-8 \
          ${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update || true
      done
    '';
  };

  environment.systemPackages = lib.mkAfter [
    pkgs.evtest # Input device debugging for touch / stylus bring-up
    pkgs.iw # Wireless debugging and scan helper for ath12k/WCN7850 bring-up
  ];

  services.udev.extraRules = lib.mkAfter ''
    # The Xiaomi factory keyboard cover can lag or repeat if USB autosuspend
    # puts the HID endpoint to sleep. Keep HID input endpoints powered on.
    SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", ATTR{bInterfaceSubClass}=="01", ATTR{power/control}="on"

    # Re-run the accessory authentication daemon when a HID keyboard is
    # attached or detached, so the keyboard cover gets re-authenticated after
    # being re-docked.
    SUBSYSTEM=="hid", ACTION=="add|remove", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="${pkgs.systemd}/bin/systemctl try-restart sheng-devauth.service"

    # Noctalia / brightnessctl need write access to the panel backlight sysfs
    # node. Ensure the video group can write it even when systemd-backlight or
    # upower do not claim the device.
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
}
