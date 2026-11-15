# Offline seed ESP for the first boot. The normal NixOS installer takes over
# once sheng-register-nix-paths has created generation 1.
{ config, lib, pkgs, ... }:

let
  system = config.system.build.toplevel;
  kernel = "${system}/kernel";
  initrd = "${system}/initrd";
  dtb = "${config.hardware.deviceTree.package}/qcom/sm8550-xiaomi-sheng.dtb";
  loader = "${lib.getLib config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
in
{
  system.build.shengEspImage = pkgs.runCommand "sheng-efi-install-esp" {
    nativeBuildInputs = [ pkgs.dosfstools pkgs.mtools pkgs.android-tools ];
  } ''
    mkdir -p "$out" esp/EFI/BOOT esp/loader/entries esp/sheng-install
    cp ${loader} esp/EFI/BOOT/BOOTAA64.EFI
    cp ${kernel} esp/sheng-install/Image
    cp ${initrd} esp/sheng-install/initrd
    cp ${dtb} esp/sheng-install/sheng.dtb
    printf 'default sheng-install.conf\ntimeout 4\n' > esp/loader/loader.conf
    printf '%s\n' 'title NixOS (first boot)' 'linux /sheng-install/Image' \
      'initrd /sheng-install/initrd' 'devicetree /sheng-install/sheng.dtb' \
      "options init=${system}/init $(cat ${system}/kernel-params)" \
      > esp/loader/entries/sheng-install.conf
    truncate -s 512M esp.img
    mkfs.fat -F 32 -n SHENGEFI esp.img
    mcopy -i esp.img -s esp/* ::/
    fsck.fat -vn esp.img
    mcopy -i esp.img ::/loader/entries/sheng-install.conf verify.conf
    cmp esp/loader/entries/sheng-install.conf verify.conf
    img2simg esp.img "$out/sheng-esp.sparse.img"
  '';

  # Retry on later boots if generation installation fails. Do not remove
  # the seed files until the standard installer has successfully run.
  systemd.services.sheng-finish-efi-install = {
    description = "Replace the first-boot EFI entry with NixOS generations";
    after = [ "sheng-register-nix-paths.service" "efi.mount" ];
    requires = [ "efi.mount" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/efi/loader/entries/sheng-install.conf";
    serviceConfig.Type = "oneshot";
    script = ''
      if [ -e /nix-path-registration ]; then
        exit 1
      fi
      ${config.system.build.installBootLoader} /run/current-system
      rm -f /efi/loader/entries/sheng-install.conf
      rm -rf /efi/sheng-install
    '';
  };
}
