# 维护交接

这份文档是接手入口，记录截至 2026-11-07（北京时间）的验证基线，不承诺这些版本永远是上游最新。
当前源码与实机状态发生变化后，请同时更新相应证据和状态，避免让会话记忆成为唯一依据。

## 当前结论与项目边界

项目使用标准 NixOS、定制主线内核和 U-Boot，不依赖 Mobile NixOS 的 rootfs 更新方式，也不要求先实现 EFI。
正常 NixOS 配置更新、内核候选系统部署及世代回退无需重新格式化 rootfs；U-Boot 本体更新仍是独立刷写操作。

单系统和双系统都保留。双系统基础适配已经验收：Android → NixOS → Android → NixOS 可重复切换，
两边测试文件保留，NixOS rebuild 和已知可用世代回退通过。外设的准确覆盖范围见
[实测矩阵](peripheral-validation.md)，未验证项目见 [TODO](../TODO.md)。

用户明确不需要 Android 原生 OTA 自动保留双系统，接受以后选择性重刷 Android。
OTA 自动化不是待交付事项。独立 `linux` 分区能保留 Linux 数据，但整包脚本仍可能覆盖 `boot_b`；
“接受重刷”不等于允许无差别刷两个槽或重建 GPT。

## 实机快照

本轮设备为 sheng 的 16 GiB RAM / 约 1 TB 存储型号。下表是这台设备的已验证布局，不是所有设备的固定布局。

| 对象 | 已验证状态 |
| --- | --- |
| Android | A 槽，`userdata` 为数据分区，`super` 内保留原有 Android 系统内容 |
| Android 版本 | Android 16，`OS3.0.304.0.WNXCNXM`；不能由 boot 组件中的 Android 13 属性推断系统实际版本 |
| NixOS | B 槽 U-Boot，根分区 `linux`，ext4，主机名 `sheng-dual` |
| 默认启动 | 本轮收尾时为 B 槽 NixOS；未来操作前重新检查 |
| 可用容量 | Android `/data` 约 477 GiB，NixOS `/` 约 487 GiB，文件系统开销和单位会影响显示值 |
| Recovery | A、B 均为同一份 sheng OrangeFox R12.0，已分别启动/校验 |
| 显示 | 默认命令行 144 Hz；笔实测时临时改为 120 Hz，结束后恢复 144 Hz |
| 控制通道 | Linux USB ACM 串口和配置后的 Wi-Fi/SSH；Android 已授权本机 ADB；Recovery ADB 可用 |
| 指纹数据 | 测试指纹已删除，fprintd 确认没有残留录入记录 |
| 笔配对 | 焦点触控笔已在 NixOS 配对并信任；未实现 Android/NixOS 配对密钥同步 |

此前所谓“单系统只占一半空间”来自已有独立 `linux` 分区和剩余 Android 系统分区，并非 NixOS 自动吞掉一半空间。
本轮复用了旧 `linux` 分区，没有重新划分 GPT。旧 Mobile NixOS 内容已被覆盖；原 `userdata` 单系统另有完整备份。
历史上两个 Linux 文件系统曾具有相同固定 UUID，所以根分区按 PARTLABEL 定位；不要照抄旧 UUID 生成挂载配置。

## 已验证版本

| 组件 | 本轮基线/选择 |
| --- | --- |
| Linux | `7.3.0-sm8550`，源提交 `1fb56e66091e71160d7c7f8e13b065d5b6ab8b8c` |
| 内核配置 | Debian-sheng 提交 `da1d2761dbc1ccaea0122f8b0c2dce2d52edaeb2` 的根目录 `sm8550.config`，叠加本项目片段 |
| Nixpkgs | `1d060086d60cb76a40cf37109f979d88a5bd6396`，NixOS `26.11.20261103.1d06008` |
| Nix | 设备端 `2.34.9` |
| U-Boot | `SushyDev/u-boot` 的 `xiaomi-sheng` 分支，锁定 `7025b792e2884c5fb4747d891e30002ea029048a`，另加本仓库补丁 |
| Zig | 0.15.2；不能直接换成 Nixpkgs 默认的较新 Zig，源码语法存在兼容性要求 |
| FastRPC / libssc / IIO | 1.0.2 / 0.4.4 / iio-sensor-proxy 3.9，沿用 Debian 方案并保留本地发现/通知修复 |
| THP / 笔状态 | 0.3.9 / 0.2.3，笔状态保留兼容 CLI |
| 指纹 | 本项目 vendored libfprint 1.94.10 后端；不能随意替换为 Nixpkgs 原版库 |
| 摄像头用户态 | 实测 libcamera 0.7.2 |

版本真值在 `flake.lock`、`packages/` 和 CI 元数据。更新 flake 不会自动把写死在 derivation 中的内核源提交改成新版本。
不要用“全部最新版”替代逐项核对，也不要把 `system.stateVersion` 当作系统升级按钮。

## 仓库和 CI 证据

- 双系统实现已在 [PR #1](https://github.com/Murkiness4095/nixos-sheng/pull/1) 合并。
- 合并后的运行代码基线为 `3cb45bc49b4b6993391d4102d563060114011b3b`。
- [单系统主分支 CI](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42241360584) 和
  [双系统主分支 CI](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42241360706) 均通过。
- KDE/GNOME 最小桌面镜像已在 [单系统 CI run 42396410220](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42396410220) 和 [双系统 CI run 42433351759](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42433351759) 构建通过，产物为 `sheng-kde-flashable`、`sheng-gnome-flashable`、`sheng-dual-kde-flashable`、`sheng-dual-gnome-flashable`；仅证明构建，不代表桌面/触控/旋转等实机验收。

| 实测对象 | 标识 |
| --- | --- |
| 单系统 toplevel | `/nix/store/hv19lpk1qbq0kimwdsklr88yq05fh9i4-nixos-system-sheng-26.11.20261103.1d06008` |
| 双系统 toplevel | `/nix/store/kdns2w3j60dshj9xdgghrk4gx94la21h-nixos-system-sheng-dual-26.11.20261103.1d06008` |
| 单系统 U-Boot SHA256 | `346f37b409ea7848b4a9d83e30f3210474a7a07259b5917f0c1ee442ee6b4d80` |
| 双系统 U-Boot SHA256 | `b9bf7df5172e007a0caef5b0243862812dd0d9bf7ec0226185bca3abdee839a6` |
| 两种模式共用内核 SHA256 | `f98773beda6a91106a3a71760ee1e1de8a4911f0a4ee9f1f66cb3905e0fa2af9` |
| 共用 DTB SHA256 | `6882a55608692133d36555b6fc241b03a20528556fed57faa2678a7b9fe3d2bc` |

已比较主分支 CI 的系统/内核/DTB 路径与实机基线，以及 U-Boot 字节/哈希。
这证明关键运行内容一致，不是宣称每次生成的 ext4 镜像逐字节相同。CI 产物有保留期限，不能依赖链接永久可下载。
文档变更不会自动重打镜像；已有镜像的 `/etc/nixos` 是构建时源码快照，不会自动同步仓库的新文档。

## 维护路径

可选 initrd 与 ext4 上的 tmpfs 根目录见 [专项说明](initrd-tmpfs.md)。默认镜像仍为传统
ext4 根目录。tmpfs 的 `/home` 默认易失，个人配置按目录选择持久化；
`sheng.rootfs.tmpfsRoot.persistHome = true` 可兼容初版的完整 home 模式。
样板用户名来自调用者参数，不绑定整个 `/var` 或 `/root`，也不保证覆盖所有应用状态。
2026-11-07 使用个人配置快照验证了 initrd 启动、tmpfs 两次启动、
Niri 登录/触摸、临时文件清空、持久数据与机器身份保留，并重启回原直启 ext4 世代。
收尾时设备运行 `/nix/store/v8njih6prk2f3b6cv5yvdsc0ghflp9ql-nixos-system-sheng-26.11.20261103.1d06008`，
个人 nix-config 工作树未被本次候选覆盖，boot/recovery/Android 分区未刷写。
后续精细模式补测了未声明 home/缓存清空、声明目录保留、服务状态与身份保留，以及
回退到同一 ext4 世代；设备最终仍为传统 ext4，详见专项说明末节。

`modules/internal-storage.nix` 为内部 UFS 的 modem、bluetooth、dsp A/B 分区及
logfs、persist、metadata、rescue、qmcs 设置 `UDISKS_IGNORE=1`，避免桌面文件管理器显示辅助卷。
规则同时匹配 UFS 控制器和 GPT 分区名，不改变分区、挂载或外接磁盘。

2026-11-07 已在用户 Niri 系统 rebuild boot 后重启验证：辅助分区的
`UDISKS_IGNORE=1` 和 UDisks `HintIgnore=true` 生效，根分区不受影响。
用户配置已固定 Niri 内屏 3048×2032 @ 120 Hz，并验证重启后自动生效及笔压事件；
这不改变命令行镜像的默认显示模式，也不构成续航优化已验收的结论。

1. 先只读检查 `hostname`、`findmnt /`、`cat /proc/cmdline`、`readlink -f /run/current-system`、`qbootctl`。
   Fastboot 中用 `fastboot getvar current-slot`。旧 DHCP 地址、槽位、世代号都可能变化。
2. 对照 CI 的 `revision.txt`、`system-path.txt`、`kernel-path.txt`、`dtb-path.txt` 和 `flake.lock`。
3. 优先比较 Debian 实际实现。一次改变一个可定位因素，在 CI 构建候选，再在设备验收。
4. 先保留已知可用世代，使用 `nixos-rebuild boot` 后重启。确认画面、控制通道、根分区和关键服务。
5. 对真正的配置/内核变化验证回退，再决定默认候选。记录准确证据，更新功能矩阵及 TODO。

### 标准更新与回退

设备端双系统配置：

```sh
sudo nixos-rebuild boot --flake /etc/nixos#sheng-dual
sudo reboot
```

个人配置沿用 `lib.shengSystem`，双系统显式保留 `sheng.rootfs.partlabel = "linux";`。
仓库的 [最小样板](../examples/minimal/README.md) 和
[flake-parts 样板](../examples/flake-parts/README.md) 默认是单系统；在使用前修改对应主机模块，不能仅改主机名就当作已完成双系统配置。
无需为了文件名习惯额外生成 `hardware-configuration.nix`；板级模块已承担内核、DTB、根挂载等职责。
不要直接搬入 x86 的 `linuxPackages_latest`、systemd-boot/EFI、NVIDIA 或 x86 磁盘布局模块。
通过 `follows` 改用用户自己的 Nixpkgs 会改变验证基线，仓库 CI 不能证明所有自定义组合都兼容。

设备本地已有输出时可以正常 rebuild；若新内核未命中可用缓存，应先走 GitHub ARM CI。
CI artifact 不是自动注册的 Nix binary cache。下载闭包后检查来源和 `SHA256SUMS`，在目标机执行：

```sh
# 在已确认模式正确的 CI system-closure 解压目录中，以 root 执行。
sha256sum -c SHA256SUMS
zstd -dc sheng-system-closure.nar.zst | nix-store --import
candidate=$(cat system-path.txt)
test -x "$candidate/init"
# 先核对 candidate 的 kernel-params：双系统必须为 root=PARTLABEL=linux。
cat "$candidate/kernel-params"
# 确认上述内容后，才设置系统 profile 并更新本机启动菜单。
nix-env -p /nix/var/nix/profiles/system --set "$candidate"
/nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

上例部署的是 CI 构建的完整系统，而不是合并用户自己的配置；个人定制仍需其对应 flake 的构建。
`nix flake update` 只更新锁文件，不部署系统、不更新 U-Boot 分区，也不保证内核源提交变更。
锁文件更新和实际部署应分开记录。

回退使用 `sudo nixos-rebuild boot --rollback` 后重启，或在 U-Boot 选择已验证世代。
世代号属于当前 rootfs 的 profile，旧单系统与新双系统的 generation 1 不是同一个系统。
旧单系统的原始 7.2.2 世代曾失败，不能当作通用救援选择；本轮双系统 generation 1 是已验证的 7.3.0 CI 系统。
手工修改 `/boot/extlinux/extlinux.conf` 或 `/boot/sheng-bootmenu.env` 会被 rebuild 覆盖。
`switch` 成功不等于新内核已经运行；内核/启动链变化仍需重启验收。
镜像中的 `/etc/nixos` 是源码拷贝，未必是 Git 工作树；不要假定可以直接 `git pull`，
应检查来源或使用用户自己的 nix-config checkout。

### CI 入口和产物

| 工作流 | 镜像 artifact | 系统闭包 artifact | 目标 |
| --- | --- | --- | --- |
| `build` | `sheng-flashable` (+ `sheng-kde-flashable`, `sheng-gnome-flashable`) | `sheng-system-closure` | `nixos`、`u-boot`、配置 `sheng` |
| `build-dual` | `sheng-dual-flashable` (+ `sheng-dual-kde-flashable`, `sheng-dual-gnome-flashable`) | `sheng-dual-system-closure` | `nixos-dual`、`u-boot-dual`、配置 `sheng-dual` |

`build` 和 `build-dual` 工作流都额外导出各自的 KDE/GNOME 桌面镜像；
它们复用同一 U-Boot，仅替换 rootfs，桌面支持目前仅完成配置求值，尚未做实机桌面验收。

镜像/内核/U-Boot 输出面向 `aarch64-linux`，上述构建命令应在 ARM CI 或已配置远程 ARM builder 的环境执行。
x86 主机默认 `packages.x86_64-linux` 没有这些板级镜像属性；可用完整
`packages.aarch64-linux.*` 属性求值，不能把属性缺失误判为板级模块失效。

两者另提供 `sheng-kernel-closure`；闭包中的归档仍叫 `sheng-system-closure.nar.zst`，以所属 artifact 区分模式。
代码 push 到 main 默认运行两种，手动触发按 workflow 分别选择，没有一个单/双系统下拉框。
重编内核优先使用 CI；已有内核闭包跨分支复用是缓存优化，新的输出路径仍需真正构建。
缓存上传收尾可能比产物生成晚，核对 artifact 已出现和整条 CI 成功是两项不同检查。

## 刷写、恢复和日志

安装和槽位切换以 [双系统指南](dual-boot.md) 为准；旧脚本的副作用见 [开发指南](DEVELOPMENT.md)。
常规 rebuild 不需要擦除分区。只恢复 B 槽 U-Boot 也不需要重刷 `linux`。
首次写入 sparse rootfs 则需要擦除目标分区，避免 DONT_CARE 空洞保留旧文件系统垃圾；这会清空该目标的数据。
A/B 是启动槽，`userdata`/`linux` 是根/数据分区，不能把两种概念混为一谈。

屏幕停在 `Starting kernel` 只说明执行到交接；应结合 USB、SSH、内核日志和根分区判断。
Linux 正常运行也可能没有 GUI，或者 USB 因 gadget/host 角色变化断开。不要仅凭黑屏重写 bootloader。

```sh
# 在 NixOS 中
uname -r
findmnt /
systemctl --failed
journalctl -b -k
journalctl -b -u sheng-alsa-ucm -u adsprpcd-sensorspd -u xiaomi-sheng-thp
systemctl reboot --reboot-argument=bootloader
```

USB tty 权限不足的临时 udev 方法，以及主机脚本的 macOS 假设，见开发指南。
一次只允许一个读取进程占用调试串口。权限不正确不能解释为设备启动失败。
内核的 g_serial 是内建组件，仅停止 getty 不代表已经释放 UDC；
关闭串口配置后的 host/DP 角色切换还需要实际验证。
无控制通道时，按键进入 fastboot，先读取槽位，再决定恢复哪一槽。
`fastboot reboot recovery` 启动当前槽 recovery；A 槽橙狐与 B 槽旧 TWRP 同时存在曾造成“橙狐被替换”的误判。
现在两槽均已验证为橙狐，不需要再次刷写来重复这个结论。
本轮使用文件名为 `OrangeFox-R12.0-peiyuesheng-sheng-20261104-0110.img`，两槽及源文件 SHA256 均为
`7c9d94398c661ef12c3890f085376a3c17fe5b0c4c8fa87cebe37fb04d776f52`。

## 本机证据与备份

本机私有证据位于仓库工作区的 `artifacts/sheng-debug/`，通过本机 Git exclude 排除，并非公共仓库内容。
换一台电脑/clone 不会自动获得这些文件。`/tmp/sheng-device-audit/` 的一次性脚本和调试密钥也不保证跨重启存在。
不要把它们作为发布脚本的固定依赖，不要把临时 SSH 地址或私钥写入公开交接文档。

| 本机路径（相对工作区） | 内容 |
| --- | --- |
| `artifacts/sheng-debug/dual-final/` | 双向切换、CI 元数据对照、最终运行状态记录 |
| `artifacts/sheng-debug/peripheral-validation/` | 触摸、键盘、笔事件摘要，音频状态，摄像头帧信息，指纹测试结果 |
| `artifacts/sheng-debug/android-audit/` | 原厂启动文件来源/校验、恢复前分区备份、Recovery/格式化日志 |
| `artifacts/sheng-debug/single-before-android/userdata-files.tar.zst` | 原 userdata 单系统的完整文件归档，含权限、ACL、xattr、store 与 Nix 数据库；不是整盘镜像 |

最后一个归档约 3 GiB（解压数据约 16.7 GB），SHA256：
`54acbbc9995f4634135cc718ee26c0ad22ec030895dd2c809b9b0309d5506a27`。
另在设备 `linux` 根文件系统的 `/root/sheng-single-backup/` 保存一份。
同目录 `.partial` 是中断传输残留，不可用于恢复。恢复归档需先准备正确的文件系统及启动链，不能直接 fastboot flash 这个 tar。

归档包含私钥、网络配置等敏感内容，只供设备所有者私下使用。指纹测试只记录状态，没有导出指纹模板。
旧 `linux` 的 Mobile NixOS 残留当次经用户确认可覆盖；该授权不能外推为今后可随时擦除新 `linux` 数据。

## 2026-11-08：桌面镜像 root 会话音频问题

KDE 用户日志明确显示 `/run/user/0/pipewire-0`，且 `pipewire.socket` 因
`ConditionUser=!root` 被跳过；这证明该次声音服务连接失败来自 root 会话。
GNOME/KDE 镜像现增加独立的 `desktop-image.nix`：普通用户 `nixos`、初始密码
`nixos`、桌面自动登录、PipeWire/Pulse/WirePlumber 和 rtkit。该模块只用于四种
桌面镜像，不加入板级模块、CLI 或个人配置构造器。
四种镜像主机名也与对应 flake 输出一致，避免默认 rebuild 误选 CLI。
两条 ARM 镜像工作流增加 `tests/desktop-images.nix` 配置回归检查。
本地检查只做配置求值，不编译内核；修复后的实际 KDE/GNOME 扬声器播放仍待验收。
默认账户及已有安装处理见 [桌面镜像账户说明](README.md#kde--gnome-desktop-image-accounts)。

修复提交 `b7716e8` 经 [PR #4](https://github.com/Murkiness4095/nixos-sheng/pull/4)
合并为 `e672b08`。以下 ARM CI 均通过，四种桌面产物均已上传：

- [单系统 42485695425](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42485695425)：`sheng-kde-flashable`、`sheng-gnome-flashable`。
- [双系统 42485695380](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42485695380)：`sheng-dual-kde-flashable`、`sheng-dual-gnome-flashable`。

上述为 PR 测试提交的产物与日志；主分支合并后的构建需另查 Actions，不能把它们混写成主分支产物。
CI 内五项配置检查均通过（四种桌面及 CLI 账户保持不变），不替代实机验收。


主分支合并提交 `e672b08` 的 [单系统 CI 42489562055](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42489562055)
和 [双系统 CI 42489561948](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42489561948)
现均已成功；四种桌面镜像已上传。PR 双系统 KDE/GNOME 产物均作只读解包核验，
普通账户、SDDM/GDM 自动登录和 PipeWire socket 已打包，根分区仍为 linux。
个人 Niri 系统的 PipeWire 播放已由用户实听确认，详见外设矩阵；没有刷写桌面镜像。

桌面用户名进一步改为 `sheng.desktop.userName` 选项，由 `image-settings.nix` 提供
默认值。两条工作流的 `desktop_username` 输入在构建前写入该文件，随镜像源码保存，
使后续 rebuild 保留账户名；TTY 镜像不创建普通用户。默认值仍为 nixos，初始密码
仍为 nixos。该后续修改的 CI 证据需单独记录，不与上述已完成构建混同。


## 2026-11-09：维护主线转向个人 Niri

用户明确不在个人平板安装或切换 KDE/GNOME；其镜像实机验收交给社区配合，
不作为 Niri 维护前置条件。当前优先测功耗、待机/唤醒，并排查用户新反馈的关机变重启。
详见 [功耗与关机验证](power-validation.md)：屏亮/熄屏对照已采集；一次 deep 自动
唤醒成功，约 40.718 秒、同一 boot ID、用户确认显示/触摸恢复，不能外推长期待机。
没有部署新系统、改默认休眠模式或刷写任何分区。关机尚未实测重现，未宣称修复。

OMP 的 host 工具提交 `4dc3e12` 仍在 `codex/find-sheng-linux-compat` 独立分支；
当前 main 的 `4c4b34f` 只覆盖此前 Linux 地址发现改动，仍含 nc -G。
后续可单独收尾该兼容性修复，但不要用 P3 工具整理替代用户明确反馈的日常体验问题。


2026-11-09 关机对照补充：同一系统拔线 `systemctl poweroff` 后保持关闭，用户长按
电源开机；接电脑 USB 后进入 U-Boot charging / Press POWER 等待，用户确认该提示。
源码 `sheng_charger_boot_poweroff()` 已有这条路径，设备 boot_b 的 boot.img 内容范围
与已检查 CI 产物哈希一致。不是 A/B 启动失败保护，不需要重置槽位。
当前缺口改为低功耗离线充电及其他供电/桌面入口的验证，不能把 U-Boot 等待当作
已经完成低功耗关机。原“关机尚未重现”的快照已由 [对照记录](power-validation.md) 更新。
平板已回到原 NixOS 登录界面，USB 已连接，SSH 可用，失败服务为 0；未刷写分区。


2026-11-09 待机后续：USB deep 三轮实际挂起 0.930 / 2.580 / 3.830 秒，属于提前
唤醒，success 增加不能当作稳定待机通过。独立跟踪记录 ipcc→glink-smem→电池
wakeup source；没有屏蔽中断或停用服务。运行时 s2idle 对照 USB 35.547 秒、拔线
180.577 秒均等到定时器恢复，用户确认相应显示/触摸，短测音频实听通过。
已恢复原 deep，未改当前系统或通用镜像；个人 nix-config 的候选参数本地提交
78eecc9，已求值/dry-build，未推送、未构建/部署。详见功耗记录与 TODO 的 18 组清单。
