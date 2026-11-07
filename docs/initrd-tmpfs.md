# 可选 initrd 与 ext4 上的 tmpfs 根目录

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

**当前策略边界：板级模块会绑定整个 `/home`，样板还保留整个 `/var` 和 `/root`。**
这是保留现有安装状态的迁移方案，不是精细的持久化白名单；用户缓存也可能一直保留。
当前模块尚未提供关闭 `/home` 绑定的选项，不能仅删掉 preservation 的用户目录清单，
就认为 home 已变成易失目录。精细用户目录持久化需要先调整板级挂载能力，再迁移选中的数据。
样板不指定用户名；用户名和应用数据清单属于个人 nix-config，不能假定覆盖所有服务状态。

```nix
sheng.rootfs.tmpfsRoot.enable = true;
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
| `/nix`、`/persist`、`/home`、`/boot` | 原 ext4 根目录下的同名目录，bind mount |

模块只负责上述启动和挂载能力。它不自动决定哪些系统状态需要持久化，
不搬移数据，不创建分区或格式化；首次使用前需确认这四个源目录存在。
只设置 enable 而不配置持久化，可能丢失重启后的网络配置、机器身份等状态。

现有 ext4 安装可参考 [preservation 样板](../examples/tmpfs-root.nix)：
直接以 `/sysroot-storage` 为后端复用原有 `/var`、`/root`、SSH、NetworkManager、
`/etc/nixos` 与 machine-id，不必把它们复制到新的 `/persist` 布局。
它需要在个人 flake 添加 preservation 输入；不要与另一个持久化模块重复管理同一路径。
用户可按需求替换持久化策略，尤其要保留自己的 SOPS 解密密钥和应用状态。

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
这与 `/home` 的策略是两件事：当前整个 home 已绑定，上述清单不会让其他 home 数据变易失。
细分用户目录时应由个人配置传入用户名（如模块参数 `user`），板级模块不指定用户。
还需按实际服务检查数据库、身份、凭据和缓存路径，不能把本样板当作无遗漏的通用清单。

## 部署与回退

启动布局变化使用 `nixos-rebuild boot` 后重启，不通过在线 switch 改变当前根挂载。
先保留已知可用世代及启动菜单，分两步验证 initrd 和 tmpfs，不直接覆盖唯一启动路径。
测试候选时也要保留其 Nix store GC root，避免未注册为世代的候选被垃圾回收。

本方案不移动原 ext4 目录，故旧世代仍可挂载原分区作为 `/`；但世代回退不能撤销
文件删除或应用数据库升级，也不会回滚持久数据。数据备份仍是独立事项。

## 实机证据（2026-11-07）

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
