{ ... }:

{
  # These firmware/Android maintenance volumes are not user storage. Match
  # the internal UFS controller as well as GPT names, never external USB disks.
  # UDISKS_IGNORE only controls desktop discovery; system mounts still work.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", KERNELS=="1d84000.ufshc", ENV{ID_PART_ENTRY_NAME}=="modem_a|modem_b|bluetooth_a|bluetooth_b|dsp_a|dsp_b|logfs|LOGFS|persist|metadata", ENV{UDISKS_IGNORE}="1"
  '';
}
