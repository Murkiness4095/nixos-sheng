{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.shengKernel;

  hardware.deviceTree = {
    enable = true;
    filter = "sm8550-xiaomi-sheng.dtb";
    name = "qcom/sm8550-xiaomi-sheng.dtb";

    # No disable-dp-altmode overlay: the sound node's dai-links include
    # DisplayPort Playback, and one unresolvable link fails the whole card.
  };

  # Stage 1 is what waits for UFS, resolves /dev/disk/by-partlabel/userdata
  # through udev and mounts the ext4 root. Without it the kernel's own
  # wait_for_root() has no timeout under `rootwait` and nothing visible to
  # report what it is waiting for.
  boot.initrd.enable = true;
  boot.initrd.systemd.enable = true;

  # UFS, ext4 and sd_mod are built into this kernel (CONFIG_SCSI_UFS_QCOM,
  # CONFIG_EXT4_FS, CONFIG_BLK_DEV_SD all =y), so stage 1 needs no modules.
  # NixOS's default list names modules this config does not build at all
  # (uhci_hcd, xhci_pci_prom21, ...), and makeModulesClosure errors out on a
  # module it cannot find instead of skipping it.
  boot.initrd.includeDefaultModules = false;

  # If the root device never appears, drop to an unauthenticated shell
  # rather than hanging. Its output goes to every registered console,
  # including ttyGS0 once the gadget console is up.
  boot.initrd.systemd.emergencyAccess = true;

  # console=tty0 pairs with fbcon=map:0 to put the log on the panel; fbcon
  # alone is not a printk target. There is no reachable UART here: uart7 is
  # disabled in the DT and the ttyMSM0 console therefore never registers.
  boot.consoleLogLevel = lib.mkDefault 4;
  boot.kernelParams = [
    "console=tty0"
    "fbcon=map:0"
    "root=PARTLABEL=${config.sheng.rootfs.partlabel}"
    "rw"
    "rootwait"
    "log_buf_len=8M"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/${config.sheng.rootfs.partlabel}";
    fsType = "ext4";
    autoResize = true;
  };

  hardware.firmware = [ pkgs.shengPackages.sheng-firmware-blobs ];
  # No CONFIG_FW_LOADER_COMPRESS in this kernel, so it cannot read NixOS's .zst.
  hardware.firmwareCompression = "none";

  hardware.bluetooth.enable = lib.mkDefault true;

  services.xserver.enable = false;

  # busybox is here for `devmem`.
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    htop
    git
    busybox
  ];
  services.openssh.enable = true;
  networking.networkmanager.enable = true;
  networking.hostName = lib.mkDefault "sheng";

  # This kernel lacks the netfilter match modules the default rules need.
  networking.firewall.enable = false;

  # Password is "password". NOT SECURE -- change before sharing.
  users.users.root.hashedPassword = "$6$e/k7.7lhroPMA6hy$ysO.xH9hAm5y0NCdKQs4AAT0MQFy0kP7F6XpVIryRAN1wNHReXXHx21zdonHiXwKuynriN9UA.OQDhhz67atj/";
  users.mutableUsers = true;

  # Set here, not as a runtime drop-in, which systemd applies first.
  services.getty.autologinUser = "root";

  system.stateVersion = lib.mkDefault "26.11";

  # debug: USB ACM console (ttyGS0); occupies Type-C, disables USB host/keyboard
  services.shengSerialConsole.enable = true;
}
