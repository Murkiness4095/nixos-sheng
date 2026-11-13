# 可选 initrd 与 ext4 上的 tmpfs 根目录

[English](./initrd-tmpfs.en.md) · 简体中文

默认单系统、双系统镜像保持 ext4 根目录直启。以下功能需要用户显式启用，
不要求 EFI、Btrfs 或 disko，不刷写 boot/recovery，也不重建 GPT。

## 只启用 initrd

在使用 `lib.shengSystem` 的个人主机模块中设置：

```nix
boot.initrd.enable = true;
```

板级内核已有 initramfs 支持；启动安装器按每个世代是否含有 `initrd` 写入
extlinux 的 `INITRD` 行。旧的直启世代仍可选择。启用后，根挂载由 NixOS
stage 1 管理，不再沿用内核直接挂载 `root=PARTLABEL=...` 的参数。

## 可选 tmpfs 根目录

`/home` 默认位于 tmpfs 根目录中，只有个人配置明确列出的用户数据会持久化。
如需沿用初版的完整 home 行为，显式设置 `sheng.rootfs.tmpfsRoot.persistHome = true;`。
初版用户升级前应选择策略并使用 boot 后重启；未列入清单的旧数据仍在原 ext4 的
`/sysroot-storage/home`，不会自动删除，但不会自动出现在新的 home 中。

```nix
sheng.rootfs.tmpfsRoot.enable = true;
sheng.rootfs.tmpfsRoot.persistHome = false;
# 上限，不是开机立即预留；默认 25%。
sheng.rootfs.tmpfsRoot.size = "25%";
# 双系统继续使用 linux；单系统默认 userdata。
sheng.rootfs.partlabel = "linux";
```

布局如下：

| 挂载点 | 来源 |
| --- | --- |
| `/` | tmpfs |
| `/sysroot-storage` | 原有 ext4 分区 |
| `/nix`、`/persist`、`/boot` | 原 ext4 根目录下的同名目录，bind mount |
| `/home` | 默认易失；`persistHome = true` 时绑定整个原 home |

模块只负责上述启动和挂载能力。它不自动决定哪些系统状态需要持久化，
不搬移数据，不创建分区或格式化；首次使用前需确认三个源目录存在；完整 home 模式还需原 `/home` 存在。
只设置 enable 而不配置持久化，可能丢失重启后的网络配置、机器身份等状态。

现有 ext4 安装可参考 [preservation 样板](../examples/tmpfs-root.nix)：
以 `/sysroot-storage` 为后端，按清单复用网络、蓝牙、NixOS、指纹/TEE、传感器等状态，
以及 SSH、`/etc/nixos` 与 machine-id；不绑定整个 `/var`、`/root` 或 home。
用户清单仅演示 Documents、Pictures、.ssh，不默认保留浏览器、聊天软件或全部配置/缓存。
样板参数 `user` 必须来自个人配置（specialArgs 或 `_module.args.user`），没有默认用户名。
`inputs` 也由调用者提供。普通 NixOS 导入可写为：

```nix
modules = [
  (import ./tmpfs-root.nix { inherit inputs; user = myConfiguredUser; })
];
```

其中 `myConfiguredUser` 是个人配置中已定义的用户名变量，不是板级选项。
若使用个人配置的 `_module.args.user`，应通过 `specialArgs` 提供 `inputs`，
或在 flake-parts 外层捕获 `inputs` 后显式传给样板；不要用依赖 `_module.args` 的值选择 imports。
它需要在个人 flake 添加 preservation 输入；不要与另一个持久化模块重复管理同一路径。
用户可按需求替换持久化策略，尤其要保留自己的 SOPS 解密密钥和应用状态。

样板覆盖当前板级服务的已知状态路径，但并不持久化整个 `/var` 或 `/root`。
`/var/lib/private` 是 DynamicUser 服务的状态容器，必须保持 0700；
蓝牙、指纹/TEE、NetworkManager 凭据目录与用户 `.ssh` 的权限在样板中单独指定。
日志、缓存、浏览器配置、聊天记录、用户 keyring、手动 `nix profile` 安装记录等不默认保留。
需要它们时添加各自的实际路径；服务启动成功不代表所有应用登录和数据体验都已验证。
若个人 nix-config checkout 放在 home 中，也必须将其实际目录列入用户清单；
保留 `/etc/nixos` 不会自动保留 home 中另一份仓库。其他旧数据仍可从
`/sysroot-storage/home` 找回，但应在首次正式启用前选好需要保留的目录。

### 增加自定义持久数据

可直接向样板已有的 `directories` 列表添加路径。也可在另一个个人 NixOS 模块中补充，
例如已有的服务数据位于 `/srv/my-service`：

```nix
preservation.preserveAt."/sysroot-storage".directories = [
  "/srv/my-service"
];
```

模块系统会合并不同模块中的列表；不要在同一个属性集中重复定义相同属性。
这个后端复用的是原 ext4 根中的同名路径。
若改用 `/persist` 后端，源路径和现有数据位置也会改变，需先规划迁移，不能只改配置字符串。
用户数据在 `preservation.preserveAt."/sysroot-storage".users.${user}.directories` 中添加，
路径相对于该用户 home。`files` 可用于单个文件；用户名由个人配置传入。
只有 `persistHome = false` 时才是精细 home 策略；设为 true 后，整个 home 都会保留。
还需按实际服务检查数据库、身份、凭据和缓存路径，不能把本样板当作无遗漏的通用清单。

## 部署与回退

启动布局变化使用 `nixos-rebuild boot` 后重启，不通过在线 switch 改变当前根挂载。
先保留已知可用世代及启动菜单，分两步验证 initrd 和 tmpfs，不直接覆盖唯一启动路径。
测试候选时也要保留其 Nix store GC root，避免未注册为世代的候选被垃圾回收。

本方案不移动原 ext4 目录，故旧世代仍可挂载原分区作为 `/`；但世代回退不能撤销
文件删除或应用数据库升级，也不会回滚持久数据。数据备份仍是独立事项。

## 初版实机证据（2026-11-07，完整 home 模式）

- initrd 候选复用原内核和 DTB，约 22 MB；成功运行 systemd stage 1 并挂载 ext4。
- 已从 initrd 候选重启回原直启 ext4 世代。
- tmpfs 候选启用 preservation，`/` 为 tmpfs，其余上述挂载来自原 ext4；
  用户确认 Niri 登录、桌面及触摸正常。
- 再次重启后，根目录测试文件消失，持久目录测试文件保留，机器 ID 和 SSH 密钥校验一致；
  当次失败服务为 0。
- 临时测试基于个人配置快照，未覆盖用户 nix-config 工作树。最终部署状态见交接记录。
- tmpfs 测试后已重启回原直启 ext4 世代，机器身份与持久数据保留，失败服务为 0；
  测试标记已删除。当前用户配置没有被默认切换为 tmpfs。

候选系统路径：

- initrd/ext4：`/nix/store/iz0gpzj8v5sm9jwmhp8ifixp9i4lwcqx-nixos-system-sheng-26.11.20261103.1d06008`。
- tmpfs/preservation：`/nix/store/g7wp9y4jn6cqfg5hzhnzczkh1qjdlm6k-nixos-system-sheng-26.11.20261103.1d06008`。

两者复用原内核 `/nix/store/0fjpqyxlnmk5sg18hwk09arzi3ivaj4d-linux-7.3.0-sheng/Image`。
对应实现为 `5125330`（initrd）与 `6429675`（可选 tmpfs），ARM CI 为
[42379410173](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42379410173)。
候选在设备 `/root/sheng-initrd-test/` 中基于个人配置快照构建；该目录含个人配置，
不是公共发布产物。测试日志保存在本机私有 `artifacts/sheng-debug/initrd-tmpfs/`。

这不证明休眠、续航或每个外设在新布局下均已回归。

## 精细 home 实测（2026-11-07）

`f8fac9b` 增加 `persistHome` 选项（默认 false），`ba6ca29` 修正样板中的敏感目录权限。
样板用户名通过个人配置传入；没有在板级模块中写入设备所有者用户名。

- 配置求值验证：精细模式没有 `/home` 挂载，`persistHome = true` 时有完整 home bind。
- 实机精细模式 `/`、`/home`、`/var` 位于 tmpfs；Pictures、Documents、网络、蓝牙、
  指纹/TEE、传感器和动态用户服务状态按清单绑定到原 ext4。
- 用户确认 Niri 登录、桌面及触摸正常；Niri 读回 120 Hz。
- 再次重启后，根目录、home 和 `.cache` 中未声明的测试文件消失，Documents 中测试文件保留；
  机器 ID、SSH 主机密钥校验一致，系统服务失败数为 0。
- 测试发现 DynamicUser 服务要求 `/var/lib/private` 为 0700，已在样板声明并冷启动复验；
  传感器初始化在隔离 bind mount 上验证能够更新内容而不删除挂载点。
- 最后已重启回原直启 ext4 世代，持久测试文件在回退后仍存在；随后删除测试标记，
  机器身份校验通过，失败服务为 0。个人 nix-config 工作树没有被候选覆盖。

ARM CI：[单系统与两份个人样板](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42386594206)、
[双系统及两种 home 策略](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42386592278)。

精细候选：`/nix/store/4zyafwrr63x1n5vg2401hssahv155dmf-nixos-system-sheng-26.11.20261103.1d06008`。
测试采用个人配置快照，源码和日志位于设备私有 `/persist/sheng-selective-test/`，
本机摘要在 `artifacts/sheng-debug/selective-home/`；这些目录不是公开发布产物。
这验证了所列操作，不等于所有应用数据都已覆盖，也没有重新测试指纹录入或快充功率。
