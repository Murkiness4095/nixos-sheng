{
  description = "NixOS and U-Boot for the Xiaomi Pad 6S Pro 12.4 (sheng, SM8550)";

  inputs = {
    u-boot-efi-src = {
      url = "github:Murkiness4095/u-boot/5d7445dfb0551aec8a3e2ad23367cabe5695351a";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Not a flake; buildUBoot just needs the tree. Override to iterate
    # without pushing: nix build .#u-boot --override-input u-boot-src ../u-boot
    u-boot-src = {
      url = "github:Murkiness4095/u-boot/xiaomi-sheng";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      u-boot-src,
      u-boot-efi-src,
    }:
    let
      # Building for this on anything else needs a remote builder.
      target = "aarch64-linux";

      hostSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forHosts = f: nixpkgs.lib.genAttrs hostSystems (s: f nixpkgs.legacyPackages.${s});

      pkgs = import nixpkgs {
        system = target;
        overlays = [ (import ./overlay.nix) ];
        config.allowUnfree = true;
      };

      ttyAccount = name: { lib, ... }: {
        config = lib.mkIf (name != "root") {
          users.users.${name}.isNormalUser = true;
          services.getty.autologinUser = lib.mkForce name;
        };
      };
      ttyUser = (import ./image-settings.nix).ttyUserName or "root";

      sheng = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [ (ttyAccount ttyUser) ];
      };

      shengDual = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          (ttyAccount ttyUser)
          {
            sheng.rootfs.partlabel = "linux";
            # nixos-rebuild --flake /etc/nixos selects this configuration by
            # hostname, rather than the single-system `sheng` configuration.
            networking.hostName = "sheng-dual";
          }
        ];
      };
      shengKde = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          { networking.hostName = "sheng-kde"; }
          ./modules/desktop-image.nix
          ./modules/desktop-kde.nix
        ];
      };

      shengGnome = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          { networking.hostName = "sheng-gnome"; }
          ./modules/desktop-image.nix
          ./modules/desktop-gnome.nix
        ];
      };

      shengDualKde = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          {
            sheng.rootfs.partlabel = "linux";
            networking.hostName = "sheng-dual-kde";
          }
          ./modules/desktop-image.nix
          ./modules/desktop-kde.nix
        ];
      };

      shengDualGnome = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          {
            sheng.rootfs.partlabel = "linux";
            networking.hostName = "sheng-dual-gnome";
          }
          ./modules/desktop-image.nix
          ./modules/desktop-gnome.nix
        ];
      };

      mkScripts =
        hostPkgs:
        let
          mk =
            name: runtimeInputs:
            hostPkgs.writeShellApplication {
              inherit name runtimeInputs;
              text = builtins.readFile (./scripts + "/${name}");
            };
          find-sheng = mk "find-sheng" [
            hostPkgs.coreutils
            hostPkgs.openssh
            hostPkgs.netcat
          ];

          mkPython =
            name: runtimeInputs:
            hostPkgs.runCommand name
              {
                nativeBuildInputs = [
                  hostPkgs.python3
                  hostPkgs.makeWrapper
                ];
              }
              ''
                install -Dm755 ${./scripts}/${name} $out/bin/${name}
                patchShebangs $out/bin/${name}
                ${hostPkgs.lib.optionalString (runtimeInputs != [ ]) ''
                  wrapProgram $out/bin/${name} \
                    --prefix PATH : ${hostPkgs.lib.makeBinPath runtimeInputs}
                ''}
              '';

          # Its own derivation, so read-blackbox cannot find it as a sibling.
          exec = mkPython "exec" [ ];
        in
        {
          inherit find-sheng exec;

          read-blackbox = mkPython "read-blackbox" [ exec ];
          capture-linux-dpu = mkPython "capture-linux-dpu" [ exec ];

          soak = mk "soak" [
            hostPkgs.openssh
            hostPkgs.coreutils
            find-sheng
          ];

          sheng-mdss-status = mk "sheng-mdss-status" [
            hostPkgs.openssh
            hostPkgs.coreutils
            find-sheng
          ];

          builder = mk "builder" [
            hostPkgs.openssh
            hostPkgs.coreutils
          ];

          flash-uboot = mk "flash-uboot" [
            hostPkgs.openssh
            hostPkgs.coreutils
            find-sheng
          ];

          flash-rootfs = mk "flash-rootfs" [
            hostPkgs.android-tools
            hostPkgs.coreutils
          ];

          fastboot-flash = mk "fastboot-flash" [
            hostPkgs.android-tools
            hostPkgs.coreutils
            hostPkgs.gnugrep
          ];
        };
    in
    {
      lib = import ./lib { inherit self; };

      nixosModules = {
        default = ./modules;
        firmware = ./modules/firmware.nix;
      };

      overlays.default = import ./overlay.nix;

      nixosConfigurations.sheng = sheng;
      nixosConfigurations.sheng-efi-generations = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          ({ lib, pkgs, ... }: {
            # The kernel already has CONFIG_EFI_STUB=y. Advertise it to systemd-boot.
            boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor (pkgs.shengKernel // {
              features = (pkgs.shengKernel.features or { }) // { efiBootStub = true; };
            }));
            boot.loader.systemd-boot.enable = true;
            boot.initrd.enable = true;
            boot.loader.systemd-boot.installDeviceTree = true;
            boot.loader.efi.canTouchEfiVariables = false;
            boot.loader.efi.efiSysMountPoint = "/efi";
            assertions = [ {
              assertion = pkgs.shengKernel.config.isYes "EFI_STUB";
              message = "The sheng EFI test kernel must enable CONFIG_EFI_STUB.";
            } ];
          })
        ];
      };
      nixosConfigurations.sheng-efi-tty = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [ (ttyAccount "nixos") ];
      };
      nixosConfigurations.sheng-dual = shengDual;
      nixosConfigurations.sheng-kde = shengKde;
      nixosConfigurations.sheng-gnome = shengGnome;
      nixosConfigurations.sheng-dual-kde = shengDualKde;
      nixosConfigurations.sheng-dual-gnome = shengDualGnome;
      # Opt-in stage-1 validation target. The normal image outputs retain
      # their known-good direct ext4 boot until hardware validation completes.
      nixosConfigurations.sheng-dual-initrd = self.lib.shengSystem {
        inherit nixpkgs;
        modules = [
          {
            sheng.rootfs.partlabel = "linux";
            networking.hostName = "sheng-dual";
            boot.initrd.enable = true;
          }
        ];
      };

      checks = forHosts (hostPkgs: nixpkgs.lib.optionalAttrs hostPkgs.stdenv.hostPlatform.isLinux {
        systemd-boot-generations = hostPkgs.testers.runNixOSTest (import ./tests/systemd-boot-generations.nix);
      });

      packages = forHosts (
        hostPkgs:
        mkScripts hostPkgs
        // nixpkgs.lib.optionalAttrs (hostPkgs.stdenv.hostPlatform.system == target) (
          {
            default = sheng.config.system.build.shengImage;

            nixos = sheng.config.system.build.shengImage;
            nixos-dual = shengDual.config.system.build.shengImage;
            nixos-kde = shengKde.config.system.build.shengImage;
            nixos-gnome = shengGnome.config.system.build.shengImage;
            nixos-dual-kde = shengDualKde.config.system.build.shengImage;
            nixos-dual-gnome = shengDualGnome.config.system.build.shengImage;

            u-boot = pkgs.callPackage ./packages/u-boot {
              src = u-boot-src;
              version = u-boot-src.shortRev or "dirty";
            };

            u-boot-dual = pkgs.callPackage ./packages/u-boot {
              src = u-boot-src;
              version = u-boot-src.shortRev or "dirty";
              rootPartition = "linux";
            };

            u-boot-efi-probe-single = pkgs.callPackage ./packages/u-boot {
              src = u-boot-efi-src;
              version = u-boot-efi-src.shortRev;
              efiProbe = true;
            };

            u-boot-efi-auto-single = self.packages.${target}.u-boot-efi-probe-single.override {
              efiAutoBoot = true;
            };

            u-boot-efi-probe = pkgs.callPackage ./packages/u-boot {
              src = u-boot-efi-src;
              version = u-boot-efi-src.shortRev;
              rootPartition = "linux";
              efiProbe = true;
            };

            kernel = pkgs.shengKernel;
            mdss-test-module = pkgs.callPackage ./packages/kernel/mdss-test-module { };
          }
          // pkgs.shengPackages
        )
      );

      apps = forHosts (
        hostPkgs:
        builtins.mapAttrs (_: script: {
          type = "app";
          program = nixpkgs.lib.getExe script;
        }) (mkScripts hostPkgs)
      );

      formatter = forHosts (hostPkgs: hostPkgs.nixfmt-rfc-style);
    };
}
