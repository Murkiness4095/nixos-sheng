{ config, lib, pkgs, ... }:

let
  cfg = config.services.xiaomi-sheng-thp;
in
{
  options.services.xiaomi-sheng-thp = {
    enable = lib.mkEnableOption "Xiaomi sheng userspace touch and Focus Pen processing";

    package = lib.mkPackageOption pkgs "xiaomi-sheng-thp" { };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "uinput"
      "uhid"
    ];
    environment.systemPackages = [ cfg.package ];

    systemd.services.xiaomi-sheng-thp = {
      description = "Xiaomi sheng NT36532E touch and Focus Pen processor";
      wantedBy = [ "multi-user.target" ];
      wants = [ "bluetooth.service" ];
      requires = [ "sheng-touchscreen-modules.service" ];
      after = [
        "sheng-touchscreen-modules.service"
        "systemd-modules-load.service"
      ];
      before = [ "display-manager.service" ];
      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Type = "simple";
        RuntimeDirectory = "xiaomi-sheng-thp";
        RuntimeDirectoryMode = "0755";
        ExecStartPre = pkgs.writeShellScript "wait-for-sheng-thp" ''
          # Firmware loading over the slow SPI path can take several seconds.
          # Wait long enough for the kernel driver to probe and expose the
          # userspace proc interfaces before giving up.
          for attempt in {1..300}; do
            if [ -r /proc/nvt_thp_stream ] && \
               [ -w /proc/nvt_thp_raw ] && \
               [ -w /proc/nvt_thp_stylus ] && \
               [ -c /dev/uinput ]; then
              echo "NT36532E THP interfaces ready on attempt $attempt"
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 0.1
          done

          echo "NT36532E THP interfaces did not become ready" >&2
          echo "Expected files:" >&2
          ${pkgs.coreutils}/bin/ls -la /proc/nvt_thp_* /dev/uinput 2>/dev/null >&2 || true
          echo "Loaded nt36532e_ts?" >&2
          ${pkgs.kmod}/bin/lsmod | grep -i nvt >&2 || true
          echo "Recent kernel messages:" >&2
          ${pkgs.util-linux}/bin/dmesg | grep -Ei 'nt36532|nvt|novatek|spi_geni|spi_qcom|firmware' | tail -50 >&2 || true
          exit 1
        '';
        ExecStart = "${cfg.package}/libexec/xiaomi-sheng-thp/xiaomi-sheng-thp";
        Restart = "on-failure";
        RestartSec = "1s";
        KillSignal = "SIGINT";
        TimeoutStopSec = "10s";
      };
    };
  };
}
