# ---
# Module: Flake Entry
# Description: Main entry point for NixOS system and Hjem
# Scope: Flake
# ---

{
  description = "Mobile NixOS rootfs for Xiaomi Pad 6S Pro (sheng)";

  inputs = {
    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos/development";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    shengKernelSrc = {
      url = "github:DotRedstone/linux-sheng/upgrade/sheng-7.1.8";
      flake = false;
    };
    shengFirmware = {
      url = "github:DotRedstone/sheng-firmware-full/719086ce25222dcc54920ae12409eb5d4401bbff";
      # Note: This is now a true flake, so we remove `flake = false;`
    };
    # Noctalia upstream flake. The `cachix` branch always points to the latest
    # commit that has already been built and pushed to the Noctalia binary cache,
    # avoiding local compilation. We deliberately do NOT make it follow nixpkgs
    # so the upstream cache remains usable.
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
  };

  outputs = { self, mobile-nixos, nixpkgs, hjem, shengKernelSrc, shengFirmware, noctalia }:
    let
      system = "aarch64-linux";
      shengOverlay = final: prev: {
        inherit shengKernelSrc;
        sheng-firmware = shengFirmware.packages.${prev.system}.default;
        libinput = prev.libinput.override {
          luaSupport = false;
        };
        libcamera-sheng = prev.libcamera.overrideAttrs (old: {
          version = "0.7.2";
          src = final.fetchurl {
            url = "https://gitlab.freedesktop.org/camera/libcamera/-/archive/v0.7.2/libcamera-v0.7.2.tar.bz2";
            hash = "sha256-bzXdR53WNKHsUIUvqXFsnagabAevk7vymQ97vYKfDf0=";
          };
          mesonFlags = (old.mesonFlags or [ ]) ++ [
            "-Dapps-output-dng=disabled"
            "-Dcam-jpeg=disabled"
            "-Dcam-output-kms=disabled"
            "-Dcam-output-sdl2=disabled"
            "-Dlibdw=disabled"
            "-Dpipelines=simple,uvcvideo"
            "-Dsoftisp-gpu=disabled"
          ];
        });
        gadget-tool = prev.gadget-tool.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or []) ++ [
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
          ];
          postPatch = (old.postPatch or "") + ''
            if grep -q "cmake_minimum_required(VERSION 2.8)" CMakeLists.txt; then
              substituteInPlace CMakeLists.txt \
                --replace-fail "cmake_minimum_required(VERSION 2.8)" \
                               "cmake_minimum_required(VERSION 3.5)"
            fi
          '';
        });
        mobile-nixos = prev.mobile-nixos // {
          kernel-builder-clang = args:
            (prev.mobile-nixos.kernel-builder-clang args).overrideAttrs (old: {
              # Temporary troubleshooting override: keep Mobile NixOS' builder
              # shape, but force the non-interactive config update while making
              # the effective mode visible in CI logs.
              configurePhase = ''
                echo "===== mobile-nixos kernel configure override: replacing oldconfig with olddefconfig ====="
                ${builtins.replaceStrings
                  [ "oldconfig" ]
                  [ "olddefconfig" ]
                  old.configurePhase}
                echo "===== mobile-nixos kernel configure override: olddefconfig configurePhase completed ====="
              '';
            });
        };
        gjs-osk = final.callPackage ./packages/gjs-osk.nix { };
        sheng-boot-animation = final.callPackage ./packages/sheng-boot-animation.nix { };
        sheng-fb-painter = final.callPackage ./packages/sheng-fb-painter.nix { };
        sheng-libssc = final.callPackage ./hardware/xiaomi-sheng/sensors/libssc.nix { };
        sheng-touch-firmware = final.callPackage ./packages/xiaomi-sheng-touch-firmware.nix { };
        xiaomi-sheng-thp = final.callPackage ./packages/xiaomi-sheng-thp.nix {
          libssc = final.sheng-libssc;
        };
        xiaomi-pen-status = final.callPackage ./packages/xiaomi-pen-status.nix { };
        # 本地覆盖：用 no-op stub 顶掉 qteesupplicant 的 QTEE RPMB listener，
        # 让 xiaomi_devauth（键盘盖认证）能拿到 service 0x2000。
        # 上游包文件保持原样，见 packages/local/qtee-rpmb-stub.nix。
        xiaomi-sheng-fingerprint =
          (final.callPackage ./packages/xiaomi-sheng-fingerprint.nix { }).overrideAttrs
            (old: {
              postInstall = (old.postInstall or "") + ''
                install -m0644 \
                  ${final.callPackage ./packages/local/qtee-rpmb-stub.nix { }}/lib/librpmbservice.so.1.0.0 \
                  $out/lib/qtee-listeners/librpmbservice.so.1.0.0
              '';
            });
        # telegram-desktop depends on kdePackages.kcoreaddons, which opts into
        # nixpkgs' per-framework Python bindings (hasPythonBindings = true).
        # Those bindings pull pyside6 -> the whole Qt6 module tree, including
        # qt3d/qtspeech, which have no aarch64 binary cache and therefore stall
        # the rootfs build. Nothing in these images uses the framework Python
        # bindings, so strip the opt-in at the scope level; each framework's
        # C++ output is unchanged.
        #
        # Dropping hasPythonBindings alone only removes the shiboken6/pyside6
        # build inputs. The matching CMake option still defaults to ON
        # (option(BUILD_PYTHON_BINDINGS "Build Python bindings" ON)), so CMake
        # keeps running find_package(Shiboken6 REQUIRED) and the build dies with
        # "By not providing FindShiboken6.cmake ... Could not find a package
        # configuration file provided by Shiboken6". Disable the option in the
        # same wrapper; the flag is only added for frameworks that opted in, so
        # packages without the option are not touched.
        kdePackages = prev.kdePackages.overrideScope (
          kfinal: kprev: {
            mkKdeDerivation =
              args:
              kprev.mkKdeDerivation (
                (builtins.removeAttrs args [ "hasPythonBindings" ])
                // prev.lib.optionalAttrs (args.hasPythonBindings or false) {
                  extraCmakeFlags = (args.extraCmakeFlags or [ ]) ++ [ "-DBUILD_PYTHON_BINDINGS=OFF" ];
                }
              );
          }
        );
        xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
          # Fallback source builds on GitHub's aarch64 runner can hit a flaky
          # notification sound-fd integration test. Release artifacts still use
          # the normal package output; this only disables build-time checks.
          doCheck = false;
        });
        libadwaita = prev.libadwaita.overrideAttrs (old: {
          # Fallback source builds on GitHub's aarch64 runner can abort in
          # libadwaita's graphical tests. Runtime output is unchanged.
          doCheck = false;
        });
        sdl3 = prev.sdl3.overrideAttrs (old: {
          # The aarch64 GitHub runner can time out in SDL3's testrwlock when
          # cache fallback forces a source build. Keep runtime output unchanged.
          doCheck = false;
        });
        SDL3 = final.sdl3;
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ shengOverlay ];
      };
      hjemModule = {
        environment.systemPackages = [
          hjem.packages.${system}.hjem
        ];
      };
      mobileEvalFor = {
        extraModules ? [ ],
        desktop ? null,
        includeDefaultUser ? false,
        includeHjem ? false,
        stage2Only ? false,
      }:
        let vars = import ./vars.nix; in
        import "${mobile-nixos}/lib/eval-with-configuration.nix" {
        inherit pkgs;
        device = ./hardware/xiaomi-sheng;
        configuration = [
          {
            _module.args = {
              inherit vars stage2Only;
            };
          }
          ({ lib, ... }: {
            nixpkgs.overlays = lib.mkAfter [ shengOverlay ];
          })
          ./configuration.nix
          # 本分支的本地平台补丁（见 docs/branch-and-merge-rules_zh.md）。
          # 上游文件保持原样，所有"上游没有但我们需要"的平台改动都放这里，
          # 这样合并上游时不会冲突。
          ./modules/sheng-local
        ]
        ++ pkgs.lib.optional (desktop == "gnome") ./profiles/gnome-minimal.nix
        ++ pkgs.lib.optionals (desktop == "niri") [
          noctalia.nixosModules.default
          ./profiles/niri-minimal.nix
        ]
        ++ pkgs.lib.optional includeDefaultUser ./profiles/local/default-user.nix
        ++ pkgs.lib.optionals includeHjem [
          hjemModule
          hjem.nixosModules.default
          ({ ... }: {
            hjem.specialArgs = { inherit vars; };
            hjem.users.${vars.username}.imports = [ ./home/user.nix ];
          })
        ]
        ++ extraModules
        ++ [
          ./hardware/mobile.nix
        ];
      };
      mobileEval = mobileEvalFor {
        includeDefaultUser = true;
        includeHjem = true;
      };
      mobileGnomeEval = mobileEvalFor {
        desktop = "gnome";
        includeDefaultUser = true;
        includeHjem = true;
      };
      mobileNiriEval = mobileEvalFor {
        desktop = "niri";
        includeDefaultUser = true;
        # Noctalia is enabled through its NixOS module; Hjem is not required
        # for this test image.
        includeHjem = false;
      };
      mobileStage2Eval = mobileEvalFor {
        desktop = "gnome";
        includeDefaultUser = true;
        includeHjem = true;
        stage2Only = true;
      };
    in
    {
      # Reuse the exact Mobile NixOS evaluations used by the flashable images.
      # This keeps nixos-rebuild generations aligned with the fixed boot image,
      # sheng kernel modules, firmware, hardware services, and desktop profile.
      # Public downstream interface. It evaluates the complete Mobile NixOS
      # platform while leaving users, credentials, Hjem, and personal
      # packages to the caller's modules.
      lib.${system} = {
        mkShengSystem = extraModules: mobileEvalFor {
          inherit extraModules;
        };
        mkShengGnomeSystem = extraModules: mobileEvalFor {
          desktop = "gnome";
          inherit extraModules;
        };
        mkShengNiriSystem = extraModules: mobileEvalFor {
          desktop = "niri";
          inherit extraModules;
        };
        # Compatibility alias. mkShengSystem is the desktop-neutral platform.
        mkShengMinimalSystem = extraModules:
          self.lib.${system}.mkShengSystem extraModules;
      };

      nixosConfigurations = {
        sheng = mobileGnomeEval;
        sheng-niri = mobileNiriEval;
        sheng-stage2 = mobileStage2Eval;
        sheng-minimal = mobileEval;
      };

      packages.${system} = {
        xiaomiShengThp = pkgs.xiaomi-sheng-thp;
        xiaomiPenStatus = pkgs.xiaomi-pen-status;
        mobileAndroidBootimg = mobileEval.outputs.android.android-bootimg;
        # rootfs 镜像的 fakeroot 属主修复在 hardware/mobile.nix 里（本分支登记的
        # 上游文件内联补丁之一），所以这里仍指向 mobile.generatedFilesystems.rootfs；
        # android-fastboot-images 也会因此拿到修好的镜像。
        mobileFastbootImages = mobileEval.outputs.android.android-fastboot-images;
        mobileRootfsImage = mobileEval.outputs.generatedFilesystems.rootfs;
        mobileRootfsImageGnome = mobileGnomeEval.outputs.generatedFilesystems.rootfs;
        mobileRootfsImageNiri = mobileNiriEval.outputs.generatedFilesystems.rootfs;
        # Compatibility alias for older workflow names. This is the Mobile NixOS
        # generated rootfs, not a separate hand-built filesystem.
        fullRootfsImage = mobileEval.outputs.generatedFilesystems.rootfs;
        mobileStage1Initrd = pkgs.runCommand "sheng-mobile-stage1-initrd" {} ''
          mkdir -p $out
          cp ${mobileEval.outputs.initrd} $out/initrd
        '';
      };

      checks.${system} = {
        bootAnimation = pkgs.runCommand "sheng-boot-animation-check" {
          nativeBuildInputs = [
            pkgs.ruby pkgs.mruby pkgs.sheng-fb-painter
            (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          ];
        } ''
          mrbc -c ${./patches/stage-1-boot-animation.rb}
          ruby ${../scripts/test-stage1-boot-animation.rb} \
            ${./patches/stage-1-boot-animation.rb} \
            ${./patches/stage-1-early-charge-guard.rb}
          python3 ${../scripts/test-boot-animation.py} \
            ${pkgs.sheng-fb-painter}/bin/sheng-fb-painter \
            ${pkgs.sheng-boot-animation}
          touch $out
        '';

        offlineCharging = pkgs.runCommand "sheng-offline-charging-check" {
          SHENG_CHARGING_FONT = "${pkgs.inter}/share/fonts/truetype/Inter.ttc";
          nativeBuildInputs = [
            (pkgs.python3.withPackages (ps: [ ps.pillow ]))
            pkgs.ruby
            pkgs.mruby
            pkgs.sheng-fb-painter
          ];
        } ''
          ${pkgs.lib.optionalString
            (builtins.elem
              "androidboot.force_normal_boot=1"
              mobileEval.config.boot.kernelParams)
            ''
              echo "androidboot.force_normal_boot=1 disables charger boot detection" >&2
              exit 1
            ''}
          ruby \
            ${../scripts/test-stage1-early-charge-guard.rb} \
            ${./patches/stage-1-early-charge-guard.rb}
          mruby \
            ${../scripts/test-stage1-udev-tolerant.rb} \
            ${./patches/stage-1-udev-trigger-tolerant.rb}
          grep -F 'output_dir="$2"' \
            ${mobileEval.config.systemd.generators.sheng-offline-charging}
          grep -F 'normal_reboot_marker=/var/lib/sheng-offline-charging/force-normal-once' \
            ${mobileEval.config.systemd.generators.sheng-offline-charging}
          grep -F 'before = [ "shutdown.target" "systemd-reboot.service" ];' \
            ${./modules/sheng-offline-charging.nix}
          python3 \
            ${../scripts/test-offline-charging.py} \
            ${./scripts/sheng-offline-charging.py} \
            ${pkgs.sheng-fb-painter}/bin/sheng-fb-painter
          touch $out
        '';
        generationMenuRenderer = pkgs.runCommand "sheng-generation-menu-renderer-check" {
          nativeBuildInputs = [
            pkgs.coreutils
            pkgs.mruby
            pkgs.sheng-fb-painter
            (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          ];
        } ''
          commands="$TMPDIR/sheng-menu.fbops"
          framebuffer="$TMPDIR/sheng-menu.raw"

          mruby \
            ${./tests/test-stage1-generation-menu-renderer.rb} \
            ${./patches/stage-1-headless-generation-menu.rb} \
            "$commands" ${pkgs.sheng-fb-painter}/share/sheng/menu-font.rb \
            ${pkgs.sheng-boot-animation}

          truncate -s $((2032 * 12288)) "$framebuffer"
          started_at="$(date +%s%N)"
          timeout 4 sheng-fb-painter \
            --file "$framebuffer" 3048 2032 12288 32 "$commands"
          elapsed_ms=$((($(date +%s%N) - started_at) / 1000000))
          test "$elapsed_ms" -lt 3000

          check_pixel() {
            offset=$((($2 * 12288) + ($1 * 4)))
            read -r blue green red alpha < <(od -An -v -tu1 -j "$offset" -N 4 "$framebuffer")
            test "$blue,$green,$red,$alpha" = "$3"
          }

          check_pixel 0 0 "0,0,0,0"
          # Rounded corner, blue selection, and the next charcoal card.
          check_pixel 940 434 "0,0,0,0"
          check_pixel 1000 540 "54,35,20,0"
          check_pixel 1000 680 "23,19,17,0"

          python3 ${../scripts/preview-generation-menu.py} "$commands" \
            ${pkgs.sheng-fb-painter}/bin/sheng-fb-painter --assets ${pkgs.sheng-boot-animation}

          echo "native framebuffer render completed in ''${elapsed_ms}ms"
          touch $out
        '';
        publicGnomeSystem =
          (self.lib.${system}.mkShengGnomeSystem [ ]).config.system.build.toplevel;
        publicMinimalSystem =
          (self.lib.${system}.mkShengSystem [ ]).config.system.build.toplevel;
      };
    };
}
