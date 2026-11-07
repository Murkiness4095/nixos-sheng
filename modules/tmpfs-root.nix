{ config, lib, ... }:

let
  cfg = config.sheng.rootfs.tmpfsRoot;
  storage = "/sysroot-storage";
in
{
  options.sheng.rootfs.tmpfsRoot = {
    enable = lib.mkEnableOption "an opt-in tmpfs root backed by the existing ext4 partition";
    persistHome = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind the entire existing /home from ext4. Disabled for selective
        persistence: /home then lives on the tmpfs root, and the caller
        chooses individual user directories through preservation or similar.
        Set true to retain the behavior of the initial tmpfs implementation.
      '';
    };
    size = lib.mkOption {
      type = lib.types.str;
      default = "25%";
      description = "Maximum tmpfs root size; memory is allocated on demand.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.enable = true;

    fileSystems = {
      "/" = {
        device = "none";
        fsType = "tmpfs";
        autoResize = false;
        options = [
          "size=${cfg.size}"
          "mode=755"
        ];
      };
      ${storage} = {
        device = "/dev/disk/by-partlabel/${config.sheng.rootfs.partlabel}";
        fsType = "ext4";
        neededForBoot = true;
        options = [ "noatime" ];
      };
    }
    //
      lib.genAttrs
        (
          [
            "/nix"
            "/persist"
            "/boot"
          ]
          ++ lib.optional cfg.persistHome "/home"
        )
        (mount: {
          device = "${storage}${mount}";
          fsType = "none";
          options = [ "bind" ];
          neededForBoot = true;
          depends = [ storage ];
        });

    # Persistent system state is caller policy. A preservation/impermanence
    # module can use /sysroot-storage as its backing directory to reuse the
    # existing /var and /etc state without copying or moving it.
  };
}
