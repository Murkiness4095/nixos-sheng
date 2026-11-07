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

  # Opt in to a standard NixOS stage 1 without changing existing images.
  boot.initrd.enable = lib.mkDefault false;
  # UFS, ext4 and the board's boot-critical drivers are built into shengKernel.
  # Generic PC modules such as ahci are not present in this kernel.
  boot.initrd.includeDefaultModules = lib.mkDefault false;
  # This board has no supported TPM; systemd otherwise adds absent PC TPM
  # modules even when includeDefaultModules is disabled.
  boot.initrd.systemd.tpm2.enable = lib.mkDefault false;

  # console=tty0 pairs with fbcon=map:0 to put the log on the panel; fbcon
  # alone is not a printk target, and serial is not connected.
  boot.consoleLogLevel = lib.mkDefault 4;
  boot.kernelParams = [
    "console=ttyMSM0,115200n8"
    "console=tty0"
    "fbcon=map:0"
    "log_buf_len=8M"
  ]
  ++ lib.optionals (!config.boot.initrd.enable) [
    "root=PARTLABEL=${config.sheng.rootfs.partlabel}"
    "rw"
    "rootwait"
  ];

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-partlabel/${config.sheng.rootfs.partlabel}";
    fsType = lib.mkDefault "ext4";
    autoResize = lib.mkDefault true;
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

  # A tablet's short power-key press must not shut down the bring-up console.
  # A desktop profile can supply its own power-key policy.
  services.logind.settings.Login.HandlePowerKey = lib.mkDefault "ignore";

  system.stateVersion = lib.mkDefault "26.11";

  # debug: USB ACM console (ttyGS0); occupies Type-C, disables USB host/keyboard
  services.shengSerialConsole.enable = true;
}
