# ---
# Module: sheng-local touch bring-up
# Description: Widens the touchscreen module/THP startup tolerance without editing upstream service definitions
# Scope: System
# Notes:
# - 两处都是"追加"，上游文件保持原样：
#   1. sheng-touchscreen-modules：上游脚本只 modprobe spi_geni_qcom 与
#      nt36532e_ts。不同内核 revision 下 GENI SPI 控制器可能叫 spi_qcom_geni，
#      这里用 ExecStartPost 补一次别名尝试，并校验 /proc/nvt_thp_stream 真的出现，
#      否则打印 dmesg 并让 unit 失败（和上游脚本里直接 exit 1 的效果一致）。
#   2. xiaomi-sheng-thp：上游 ExecStartPre 只等 100 × 0.1s = 10s；SPI 路径上的
#      固件加载实测会更慢。这里用 mkBefore 在它前面再等 300 × 0.1s = 30s，
#      总容忍度 40s（比原来本地的 30s 更宽松），失败时输出诊断。
# - 上游若自行加长等待或接受别名逻辑，可删除对应部分。
# ---
{ lib, pkgs, ... }:

{
  systemd.services.sheng-touchscreen-modules.serviceConfig.ExecStartPost = lib.mkAfter [
    (pkgs.writeShellScript "sheng-touchscreen-modules-postcheck" ''
      # The QCOM GENI SPI controller may be exported under either module name
      # depending on the kernel revision. Try both before verifying the touch
      # driver, so the SPI device is actually present on the bus.
      for module in spi_geni_qcom spi_qcom_geni; do
        if ${pkgs.kmod}/bin/modinfo "$module" >/dev/null 2>&1; then
          ${pkgs.kmod}/bin/modprobe "$module" || true
        fi
      done
      sleep 1

      ${pkgs.kmod}/bin/modprobe nt36532e_ts || true
      sleep 1

      # Verify the driver really probed and exposed its proc interface.
      # If it did not, dump the last relevant dmesg lines for diagnosis.
      if [ ! -e /proc/nvt_thp_stream ]; then
        echo "nt36532e_ts proc interface missing after modprobe" >&2
        ${pkgs.util-linux}/bin/dmesg | grep -Ei 'nt36532|nvt|novatek|spi_geni|spi_qcom' | tail -50 >&2 || true
        exit 1
      fi
    '')
  ];

  systemd.services.xiaomi-sheng-thp = {
    requires = lib.mkAfter [ "sheng-touchscreen-modules.service" ];
    serviceConfig.ExecStartPre = lib.mkBefore [
      (pkgs.writeShellScript "wait-for-sheng-thp-extra" ''
        # 上游的 ExecStartPre 只等 10 秒。先在这里多等 30 秒，让上游那个较短的
        # 等待必然成功；两边都超时才失败，并打印诊断信息。
        for attempt in $(seq 1 300); do
          if [ -r /proc/nvt_thp_stream ] && \
             [ -w /proc/nvt_thp_raw ] && \
             [ -w /proc/nvt_thp_stylus ] && \
             [ -c /dev/uinput ]; then
            echo "NT36532E THP interfaces ready on extra attempt $attempt"
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.1
        done

        echo "NT36532E THP interfaces did not become ready within the extra wait" >&2
        echo "Expected files:" >&2
        ${pkgs.coreutils}/bin/ls -la /proc/nvt_thp_* /dev/uinput 2>/dev/null >&2 || true
        echo "Loaded nt36532e_ts?" >&2
        ${pkgs.kmod}/bin/lsmod | grep -i nvt >&2 || true
        echo "Recent kernel messages:" >&2
        ${pkgs.util-linux}/bin/dmesg | grep -Ei 'nt36532|nvt|novatek|spi_geni|spi_qcom|firmware' | tail -50 >&2 || true
        exit 1
      '')
    ];
  };
}
