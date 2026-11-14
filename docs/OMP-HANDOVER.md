# OMP 接手清单与维护流程

[English](./OMP-HANDOVER.en.md) · 简体中文

更新日期：2026-11-14（北京时间）。这是本次会话交接快照，状态会变化，执行前重新核对。
先读 [AGENTS.md](../AGENTS.md)、[维护交接](HANDOVER.md)、[TODO](../TODO.md)、
[外设实测矩阵](peripheral-validation.md)。历史记录不能覆盖当前源码和实机结果。

## 2026-11-14 EFI 接续点

- 单、双系统临时 EFI 已通过，单系统两代已分别在真机启动。标准安装器在 VM 及平板临时 FAT ESP 上通过两代更新与回滚。RAM FAT32 已实机加载完整 Linux。详见 [EFI 实测记录](efi-probe.md)。
- 最后一次串口确认平板回到 extlinux 第 18 世代，根后端为 `linux`。测试经 B 槽 ABL 临时启动，未调整实际 GPT 或刷写 boot 分区。重新接手时复核槽位、PARTLABEL、系统路径和可用控制通道。
- `codex/efi-fat-probe` 保存 RAM FAT 原型及 CI 43572104110 的源码；`codex/efi-sheng-closure` 保存两代闭包构建及 CI 43568095098 的源码。保留两分支供复现。稳定 U-Boot 源是 `xiaomi-sheng`，EFI 仍锁定到 `5d7445dfb055`。
- 下一步是对比持久布局并写出可逆迁移方案。本机主 UFS 无未分配空间；约 512 MiB 的 ESP 只在临时磁盘镜像上演练。先复核备份和恢复路径，准备从内置 FAT ESP 加载 fallback 的临时 U-Boot 候选。真实分区缩容或刷写须有对应授权。
- 持久链路验收：从 ESP 启动、标准世代更新、重启新世代、回滚并重启，以及 extlinux 救援。之后再从实验分支提取必要的 U-Boot 改动并回归 extlinux。单系统音频实听和刷入正式自定义 TTY 镜像后的登录仍未验收。

## 2026-11-09 历史接续点

PR #5 已合并，两路主分支构建通过；用户不在个人平板切换 KDE/GNOME，相关实机验收
交给社区。当前重点 D01：现有 Niri 功耗与挂起到内存（suspend）稳定性；不是需要
swap 的休眠到磁盘（hibernate）。完整去重清单在 [TODO](../TODO.md)，共 18 组。

已完成屏亮/熄屏基线与一次拔线 deep 自动唤醒；后续 USB 两轮提前唤醒，需按实际
BOOTTIME−MONOTONIC 增量判断，不能只看 success 计数。详见 [专项记录](power-validation.md)。
拔线 poweroff 正常，USB 关机进入已确认的 U-Boot charging 等待，未改 bootloader。
以下早期快照中的“PR #5 待收尾/CI 运行中”已过时，保留为历史上下文。

## 当前进度

| 项目 | 已完成 | 尚未证明 / 下一步 |
| --- | --- | --- |
| 标准 NixOS + U-Boot | 启动修复、7.3.0、正常 rebuild、世代回退 | 不需要为了 tmpfs 增加 EFI |
| 单 / 双系统 | 单系统 userdata；参考双系统 Android A / NixOS B、linux 根；双向切换与数据保留通过 | 保留两种独立输出；Android OTA 自动化不在范围内 |
| initrd / tmpfs | 可选 initrd、ext4 后端、声明目录持久化、未声明文件重启清空、传统 ext4 回退通过 | 默认镜像仍为传统 ext4；应用数据须按需声明 |
| 当前个人系统 | tmpfs 根、选择性持久化、Niri/触摸正常；SSH、网络、蓝牙、机器身份等持久化已核对 | 不等于每个应用的登录状态、存档都已覆盖 |
| 桌面音频修复 | PR #4 已合并；root 会话导致 ConditionUser=!root 跳过 PipeWire 的根因明确 | KDE/GNOME 新镜像仍需真实登录和扬声器实听 |
| 普通用户镜像 | 四种桌面镜像加入普通用户、自动登录和音频服务；主机名匹配 flake 输出 | PR #5 已合并：构建时可通过 `desktop_username` 或 `sheng.desktop.userName` 自定义用户名，默认 `nixos`
- 用户名自定义：PR #5 已合并，合并提交 `4d1fa36d66a1cb8cf42f6b3bbb6093f6503b9048`；
  单系统 CI [42505507706](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42505507706)、
  双系统 CI [42505507751](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42505507751) 均为 success。
  PR 分支 CI [42495329443](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42495329443)、
  [42495329344](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42495329344) 也为 success。

TTY 镜像保持 root 命令行自动登录，默认 root 密码 `password`；不新增桌面用户。
桌面镜像初始密码为 `nixos`；PR #5 将用户名做成可配置项，默认值为 `nixos`。
安装后应调整密码和登录策略。不要把个人用户名写成仓库模板的固定要求。

## 代码与 CI 证据

- 主分支：PR #4 合并提交 `e672b0823279fe660a54a302c0fe6de7a5d24f67`；
  随后的文档提交 `8527e54`。主分支四种桌面产物已成功构建：
  [单系统 42489562055](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42489562055)、
  [双系统 42489561948](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42489561948)。
- 待收尾：[PR #5](https://github.com/Murkiness4095/nixos-sheng/pull/5)，分支
  `codex/configurable-desktop-user`，提交 `a1bda22a5b283afee0d9006b71dd51f59e874e26`。
  [单系统 CI 42495329443](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42495329443)、
  [双系统 CI 42495329344](https://github.com/Murkiness4095/nixos-sheng/actions/runs/42495329344)
  在本次快照时运行中。接手先查实际结果，不能直接当作通过。
- PR #5 相关文件：`image-settings.nix`、`modules/desktop-image.nix`、两条 workflow、
  `tests/desktop-images.nix`、账户说明及本轮外设证据。
  `desktop_username` 输入写入跟踪的 `image-settings.nix`，随后正常构建原有输出；
  文件随 `/etc/nixos` 源码进入镜像，后续 rebuild 保留所选名字。
  也可通过 `sheng.desktop.userName` 覆盖。只对桌面镜像生效。

## 实机快照

本轮只读检查：主机名 `sheng`，`/run/current-system` 与 `/run/booted-system` 相同：

```text
/nix/store/v6sdp26sdgnffxcrk2pgdriapf9syd10-nixos-system-sheng-26.11.20261103.1d06008
```

根目录是 tmpfs；`/sysroot-storage` 是原 ext4 后端；系统 profile 当时指向
`system-11-link`，失败服务为 0。槽位与 PARTLABEL 在本次交接检查中没有重新读取，
执行写入前必须重新确认，不要由历史 B 槽或 `/dev/sda30` 推导当前写入目标。
本轮没有刷写 KDE/GNOME 镜像，也没有为桌面问题刷 U-Boot。

SSH 私钥以 `/persist/etc/ssh/` 为准，已同步到后端旧 `/etc/ssh/`；权限为 root:root、
私钥 0600，比较一致。旧副本备份只保存在设备私有目录，不发布密钥或其原始备份。
个人配置在另一个工作区 `nix-config`，不要覆盖用户后来修改的持久化目录列表。
当前 home 没有整体绑定，但用户可主动选择持久化 `.config`、`.local/share` 等目录；
这不等于所有应用都必须这样配置。

音频：个人 Niri 普通用户会话的 PipeWire / Pulse / WirePlumber 为 active，
默认 Speakers，`pw-play` 两秒轻提示音返回成功，用户确认听到。
KDE 用户反馈的 root 会话问题与此不同，仍须用新版 KDE/GNOME 实机验证。

## OMP 下一步，按优先级

1. **收尾 PR #5**：核对两条 CI、失败日志和产物；失败则定位修复，通过后合并，
   并记录合并后的源提交及主分支构建。不要把 PR #4 的通过结果当作 #5 的证明。
2. **自定义用户名证据**：模块覆盖与 workflow shell 已本地检查；如需证明真实自定义
   打包路径，可选择一次 `workflow_dispatch` 输入非默认用户名，核对账户、SDDM/GDM、
   `/etc/nixos/image-settings.nix`，避免重复触发同一配置的整套镜像构建。
3. **桌面镜像实测**：优先让 KDE 反馈者试新版，收集 `whoami`、系统路径、用户服务、
   `wpctl status` 和实际出声结果。GNOME 同样记录。构建成功、只读解包、Niri 实听均不能
   替代 KDE/GNOME 登录验收；不要为这一步直接覆盖所有者的个人系统。
4. **持久化应用范围**：按用户实际应用补充最小目录，保留基础 SSH、网络、机器身份；
   新增迁移先核对现有数据和权限。无需重新移植 tmpfs，也不要默认绑定整个 home。
5. **日常体验**：按 TODO 逐项做待机/唤醒与耗电、桌面旋转、笔绘画/重连、音频路由等。
   优先参考 Debian-sheng 的真实实现；一次解决一个可复现问题。

USB host / DP、蓝牙音频、最高充电功率、完整桌面指纹/PAM、全部摄像头应用等仍按
外设矩阵标为待验收。无需重复指纹录入；历史测试数据已按用户要求删除。

## 实际使用并整理后的工作流

### 1. 开始先确定现场，限定本次改动

- 读上述入口，检查 `git status`、分支、最近提交、远端 PR 与 CI。
- 不覆盖其他 agent 或用户的未提交修改；个人 nix-config 与板级仓库分别处理。
- 先核对设备模式、系统路径、根分区标签、槽位和可用控制通道；SSH 地址和 tty 权限会变。
- 用户要求“仅回答”就不改代码；用户明确继续后完成授权范围，不每一步再询问。

### 2. 定位根因，再改最小范围

本次音频问题先读 `systemctl --user` 日志，看到 `/run/user/0` 和
`ConditionUser=!root`，才修改桌面账户；没有改内核声卡驱动或绕过安全条件。
单/双系统、TTY/桌面、仓库默认/个人配置分开，避免把个人用户、目录或分区标签写死。
内核与外设方案优先核对 Debian-sheng 实际源码、固件、包及服务集成。

### 3. 本地做便宜而有意义的检查

- Nix 改动先求值相关配置、选项、完整 toplevel drvPath；输入处理做有效/无效值检查。
- 新文件先纳入 Git 跟踪再 flake 求值，避免因未跟踪而“文件不存在”。
- 使用 `nix eval .#...` 或 Git flake 源。工作区路径有空格时显式 URI 编码，例如
  `git+file:///mnt/data/vibe%20coding/xiaomipad6spro/nixos-sheng`。
- 不用 `path:` 把整个工作区复制进 store：它可能包含被 Git 忽略的私有证据和备份。
- 文档只做事实、链接与 `git diff --check` 检查，不重新编译内核。
- 测试通过后，除非有新修改或未解决问题，不重复扩大检查。

### 4. 重构建放 GitHub ARM CI

- 小改动放 `codex/` 分支并建 PR，检查两种产品模式；PR 已自动触发时不要再手动
  dispatch 一模一样的构建。本轮曾有重复 dispatch，已取消，后续避免。
- 按实际所需复用内核 closure，锁定 source / flake.lock / CI head SHA。
  检查下载/导出缓存是否真成功，不因本机缺缓存就默默在 x86 或平板编译内核。
- 看检查状态与失败步骤，必要时拉失败日志；长步骤等待期间只报告有用进展。
- 构建通过后再合并；主分支产物与 PR 产物分别记录，不能混用来源说明。
- 独立交接文档尽量单独 docs-only 提交，避免推到运行中的功能 PR 后取消并重跑重构建。

### 5. 先检查产物，后部署候选

本轮使用 `gh run download` 获取指定桌面 artifact，`zstd -d --long=27` 解压，
`simg2img` 转为 ext4，再用现成 `debugfs` 只读查看：

- extlinux 的 init 系统路径、root PARTLABEL、kernel / DTB 路径；
- 系统 activate 引用的 users-groups JSON；
- SDDM / GDM 配置、PipeWire sockets 与启用链接。

这不需要挂载或刷写设备，也不证明桌面交互可用。下载较大，按待核验项目选择一次，
不要为每次状态查询反复下载镜像。原始命令、审计脚本和产物位于本机忽略目录
`artifacts/sheng-debug/desktop-audit/`，不保证换机后存在，不作为公共工作流依赖。
其内两套桌面产物来自 PR #4 的双系统 CI，而非 PR #5 或当前实机。

需要实机更新时保留已知可用系统路径及控制通道，用候选世代和正常 rebuild 流程；
对中断当前桌面的重启/注销先说明影响。更新系统不要求擦 rootfs。
双系统不运行会写两槽/擦 userdata 的旧通用刷写脚本。
U-Boot 候选优先临时启动，不能用重刷 U-Boot 代替定位未解释的黑屏。

### 6. 实测结果按证据分层记录

区分求值、构建、打包检查、服务运行、事件采集、用户实际交互。
只在确需用户操作时请其配合：如听声音、画笔、确认桌面；说明动作与判断标准，
不要重复让用户录指纹或在未准备采集时要求动作。
修改硬件链路后验证候选、回退及关键功能；保留前后系统路径与测试范围。
日志公开前剔除私钥、Wi-Fi 配置、签名下载地址、生物识别数据。

### 7. 完成后交付；中断时留清楚状态

更新 HANDOVER、TODO 与具体测试矩阵，说明改了什么、为何改、检查结果和剩余边界。
尊重“停一下”：停止新修改，说明仍在后台执行的下载、监视或 GitHub CI；
不要将结束聊天误报为远程 CI 已取消。
接手者先重新检查状态，再从上述待办接续，不能只凭上一个 agent 的总结下结论。

## 快速状态命令

```sh
git status --short
git log -5 --oneline
gh pr view 5 --json state,headRefOid,statusCheckRollup
gh run list --branch codex/configurable-desktop-user --limit 4
```

个人配置与私有设备证据不要作为这份公共文档的附件上传。
