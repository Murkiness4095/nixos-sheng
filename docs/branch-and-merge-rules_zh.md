# 分支结构与合并规则

[English](branch-and-merge-rules.md) | [简体中文](branch-and-merge-rules_zh.md)

本文档规定本仓库的分支职责、内容分层和合并上游的流程。改代码前先读这里，
`AGENTS.md` 只写协作与刷机边界。

## 1. 分支职责

| 分支 | 职责 | 谁改 | 产物 |
|---|---|---|---|
| `sheng` | 上游平台线镜像，只读 | 只 `git fetch upstream` 后 fast-forward | 不构建 |
| `niri` | **日用线**：上游 sheng + 本地平台补丁 + Niri/Hjem 桌面层 | 只在这里加功能 | `mobileAndroidBootimg`、`mobileRootfsImageNiri`（CI 从这里出镜像） |
| `exp/kernel-sm8550-7.2.6` | 内核实验线：`niri` + 最新内核 pin | 只在换内核时动 | boot + modules 归档 |

已删除的旧分支（内容都已并入 `niri`，SHA 留档以便回滚/对比）：

| 旧分支 | SHA | 说明 |
|---|---|---|
| `exp/niri-merge-upstream-sheng` | `a8ecd40` | 重构前的 niri+sheng 集成线内容 |
| `feat/niri-noctalia-image` | `24c36da` | 重构前刷入用的 niri tip（7.1.8） |

需要临时看回来时：`git branch <name> <sha>` 或
`git push origin <sha>:refs/heads/<name>`。

## 2. 内容分三层，落点不要放错

| 层 | 内容 | 放哪 | 上游会不会动 |
|---|---|---|---|
| 上游平台 | boot/充电界面、离线充电、内存策略、固件注入、内核 pin | 不改，直接跟随 `sheng` | 经常动（近 30 天 100+ 提交） |
| 本地平台 | 上游没有、但本机需要的平台修复 | `nixos/modules/sheng-local/*.nix`（自己的文件） | 不会动 → 永不冲突 |
| 桌面 | Niri/Noctalia/Hjem、桌面软件包、用户配置 | `nixos/profiles/niri-minimal.nix`、`nixos/home/user.nix`、`nixos/profiles/local/*` | 不会动 |

**硬规则：新增平台功能不要改上游文件。** 用 NixOS 模块的追加能力实现：

- 加服务 / 加 unit 字段：直接写新服务，或 `lib.mkAfter` / `lib.mkBefore`
  （`wants`、`after`、`requires`、`ExecStartPre/Post`、`environment.systemPackages`、
  `services.udev.extraRules`、`hardware.firmware` 都是可追加的 list/lines 选项）
- 改上游某个字符串选项：用 `lib.mkForce`（注意：上游用 `lib.mkForce` 包住整个
  attrset 时，**子选项的 `mkForce`/`mkOverride` 会被静默忽略**，必须改上游那一行，
  或者像 `mobile.nix` 那样登记为内联补丁）
- 改包的行为：在 flake overlay 里 `overrideAttrs` 追加 `postInstall`，不要改上游包文件
- 改 profile 的行为：写一个自己的 profile 文件 `imports = [ 上游 profile ]` 再覆盖

## 3. 合并上游 sheng

```bash
git fetch upstream
git checkout niri
git merge upstream/sheng
```

冲突按下面规则处理，不要每次重新判断：

| 冲突文件 | 规则 |
|---|---|
| `nixos/modules/sheng-local/*`、`nixos/profiles/local/*`、`nixos/profiles/niri-minimal.nix`、`nixos/home/user.nix`、`nixos/packages/local/*` | 我们的（上游不会碰，正常不会冲突） |
| `nixos/flake.nix`、`nixos/flake.lock` | 我们的：保留 fork 内核源/hjem/noctalia 与本地模块接线，同时吸收上游新增的包与选项 |
| `nixos/configuration.nix`、`nixos/hardware/mobile.nix` | 上游优先，**只保留第 4 节登记的 4 处补丁**（带 `LOCAL PATCH` 注释） |
| `.github/workflows/*`、`README*`、`TODO*`、`docs/*`、`AGENTS.md`、`build-nixos-rootfs.sh`、`examples/*` | 取并集；CI 以我们的为准 |

`git rerere` 已在本仓库开启（`rerere.enabled=true`、`rerere.autoupdate=true`），
同一处冲突解一次之后会自动复用解法。新克隆的仓库需要自己再开一次：

```bash
git config rerere.enabled true
git config rerere.autoupdate true
```

## 4. 登记的上游文件内联补丁（只有 4 处）

| 文件 | 补丁 | 为什么不能放本地模块 |
|---|---|---|
| `nixos/hardware/mobile.nix` | rootfs 的 `mkfs.ext4` 阶段包一层 `fakeroot` 并 `chown -R 0:0` | 上游用 `lib.mkForce` 定义整个 `mobile.generatedFilesystems.rootfs`，模块系统会吞掉子选项覆写；镜像内文件非 root 属主会让 NetworkManager 拒绝加载 wifi 插件（`nmtui` 空列表） |
| `nixos/hardware/mobile.nix` | 删除 `boot.bootspec.enable = ...` | 该选项在当前 nixpkgs 已移除，只要被定义就断言失败，`sheng-stage2` 直接求值不了；无法用模块取消别人的定义 |
| `nixos/configuration.nix` | `services.journald.extraConfig` → `services.journald.settings.Journal` | 同上：`extraConfig` 已移除，被定义即断言失败 |
| `nixos/configuration.nix` | wireplumber `libpipewire-module-filter-chain` 组件 `type` 由 `pw-module` 改为 `pw-module-client` | 该键是 `attrsOf (attrsOf json)` 的 json 叶子，覆写要整块复制上游的 EQ 图，会冻结上游调音；改一行更安全（否则整机无声） |

另外 `nixos/scripts/sheng-check.sh` 有本地追加的诊断命令（纯附加、上游 30 天未改动），
一并按"我们的"处理。

合并后检查这几处还在：

```bash
grep -n 'LOCAL PATCH' nixos/configuration.nix nixos/hardware/mobile.nix
```

## 5. 新增功能的落点

1. 桌面相关（会话、软件包、主题、快捷键）→ `nixos/profiles/niri-minimal.nix`
   或 `nixos/profiles/local/*`、`nixos/home/user.nix`
2. 平台相关（驱动加载、服务、udev、固件、电源）→ `nixos/modules/sheng-local/`
3. 内核相关（DTS、驱动、config）→ 内核仓库 `DotRedstone/linux-sheng`（或本分支的
   内核 fork），本仓库只改内核 pin
4. 确实要改上游文件时：先按第 2 节的覆写手段试一遍，都不行才登记为内联补丁，
   并在这里补一行说明

## 6. 合并后的验证要求

求值级（本地就能做，改完必跑）：

```bash
nix build --dry-run --offline --system aarch64-linux ./nixos#mobileAndroidBootimg
nix build --dry-run --offline --system aarch64-linux ./nixos#mobileRootfsImageNiri
nix build --dry-run --offline --system aarch64-linux ./nixos#nixosConfigurations.sheng-stage2.config.system.build.toplevel
nix build --dry-run --offline --system aarch64-linux ./nixos#checks.aarch64-linux.generationMenuRenderer
```

行为等价性（重构或合并后推荐做一次，见 `docs/` 里的对比方法）：对
`nixosConfigurations.sheng-niri.config` 的以下项求值并逐项比对：rootfs
`buildPhases.copyPhase`、`boot.kernelParams`、`hardware.firmware` 聚合、udev 规则、
`environment.systemPackages`、`systemd.services.{sheng-wifi-modules,sheng-nm-wifi-sync,
sheng-touchscreen-modules,xiaomi-sheng-thp,sheng-devauth}`、`services.journald.settings`、
`services.openssh.settings.PasswordAuthentication`、wireplumber 组件、Noctalia 亮度配置。

设备级：只有实机能验的项（启动画面、离线充电、触摸、键盘盖认证、nmtui 列表、
指纹）在刷机后按 `docs/` 里的检查命令逐条确认。

## 7. 刷写边界

| 改动 | 构建 | 刷 |
|---|---|---|
| kernel config / patch / DTS / initrd / cmdline | `mobileAndroidBootimg` | `boot_b` |
| 内核模块（`.ko`） | 内核归档 | `linux` 里的 `/lib/modules`（或用设备内 `nixos-rebuild`） |
| firmware / systemd / udev / 包 / 桌面 / rootfs 布局 | `mobileRootfsImageNiri` | `linux` |

设备内更新（不刷镜像）见 `docs/nixos-rebuild_zh.md`：flake 里的 `sheng-niri` /
`sheng-stage2` 就是为这条路准备的；前提是 flake 的内核 pin 与已刷 `boot_b` 的内核一致。

CI 注意：`build-nixos-rootfs.sh` 会把镜像转成 **Android sparse 格式**
（`img2simg`，便于 fastboot 直接刷）。任何需要挂载或读取镜像内容的 CI 步骤都必须先
`simg2img` 转回 raw 再 `mount`，否则会报 `wrong fs type, bad option, bad superblock`。
上游新增的校验步骤默认按 raw 镜像写，合并上游后要检查这一点
（`nixos-rootfs.yml` 的 "Verify hardware payloads in rootfs"）。
