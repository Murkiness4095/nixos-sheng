# ---
# Module: sheng-local default user profile
# Description: Wraps upstream's default-user profile so images built with an explicit password hash can be logged into over SSH
# Scope: System
# Notes:
# - 上游 profiles/default-user.nix 里 PasswordAuthentication 带 !localTestAccess，
#   于是 CI 用 user_password_hash 构建的镜像无法用密码 SSH 登录，调试不方便。
# - 这里不修改上游文件，而是包一层：导入上游 profile 后用 mkForce 放宽。
#   不用这个 profile 的求值（下游 dotfiles）不受影响。
# ---
{ lib, vars, ... }:

let
  userHasPassword = vars.userPasswordHash != null || vars.userPassword != null;
in
{
  imports = [ ../default-user.nix ];

  # If the builder explicitly supplied a password hash, allow SSH password
  # authentication so they can log in remotely for debugging. Local test
  # images without a password still keep password auth disabled.
  services.openssh.settings.PasswordAuthentication = lib.mkForce userHasPassword;
}
