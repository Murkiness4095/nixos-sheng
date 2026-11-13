# Niri 日常功耗与休眠验证

[English](./power-validation.en.md) · 简体中文

2026-11-09 开始。用户继续使用现有 Niri，不在其平板安装、刷入或切换 KDE/GNOME。
桌面镜像实机验收保留为社区待测，不阻塞这台平板的维护。

这里的 deep / s2idle 都是**挂起到内存（suspend）**，不需要 swap。
写入磁盘的休眠（hibernate）是另一条功能，未在本轮配置或测试。

## 目标与顺序

1. 固定现有系统、刷新率和亮度，拔线记录两分钟屏亮空闲读数。
2. 通过 Niri 临时关闭显示做对照；准备独立自动恢复，再采集，结束后恢复显示。
3. 区分显示耗电、后台负载与电源管理能力；单一 sysfs 读数不直接当整机精确功率。
4. 再单独规划挂起/唤醒：记录 boot ID、成功/失败计数及实际睡眠时间，准备恢复通道，
   验证显示、触摸、音频、网络和蓝牙恢复。先做只读检查，用户确认在场且工作已保存后再测试。
5. 根据数据选择一个修复，优先比对 Debian-sheng 的配置/源码，再做候选与回退验证。

临时显示开关不修改用户配置。不会为功耗排查改写 PMIC、刷 U-Boot、格式化分区、
盲目关闭硬件或把其他平台的 s2idle/deep 经验直接套成默认设置。

## 初步只读检查

系统：`/nix/store/v6sdp26sdgnffxcrk2pgdriapf9syd10-nixos-system-sheng-26.11.20261103.1d06008`；
根目录 tmpfs，失败服务数 0。Niri 内屏 3048×2032、120 Hz、缩放 2.25；
背光值 1146/2047（数值比例，非线性亮度或实测亮度）。
CPU 使用 schedutil、PSCI idle、menu governor；GPU 为 simple_ondemand。
`mem_sleep` 为 `s2idle [deep]`；本次检查成功/失败休眠计数均为 0，不能据此宣称休眠已通过。

power-profiles-daemon 当前显示 power-saver，但 `powerprofilesctl list` 的 PlatformDriver
为 placeholder。不能凭界面模式名称推断已经启用具体硬件省电策略。
电池 `power_now` 返回 0，不能作为实际零功耗；电流符号和报告口径须结合场景核对。

私有原始证据位于本机忽略目录 `artifacts/sheng-debug/power-2026-11-09/`。
不把短时电量百分比不变当作无耗电。


## 本轮结果

| 场景 | 采样 | 平均报告电流 | V×绝对电流粗估 | 全机 CPU 平均忙碌 |
| --- | --- | --- | --- | --- |
| 拔线、120 Hz、原背光、屏亮空闲 | 120 秒，13 点 | -735231 µA | 2.874 W | 3.37% |
| Niri 关闭显示，先稳定 15 秒 | 随后 60 秒，7 点 | -213143 µA | 0.836 W | 1.17% |

两组电池百分比均为 57%，报告温度均约 20.7°C。V×I 只是电量计读数的粗估，
未校准电池组报告口径或用外部仪表核对，不能据此承诺续航；此处重点是同一设备
同一系统下熄屏前后的差异。显示关闭后报告电流绝对值下降约 71%，说明显示是这组
空闲状态的重要因素；CPU 读数没有证明存在高占用。没有改刷新率或持久省电配置。

随后经用户确认做一次当前 deep 模式休眠，设置 WakeSystem 日历定时器自动唤醒：
boot ID 保持不变，success 从 0 到 1，fail 保持 0；CLOCK_BOOTTIME 与 MONOTONIC
增量之差约 40.718 秒。SSH 自动恢复，用户确认 Niri 显示和触摸正常。
日志有 `hwmon hwmon41: PM: parent phy0 should not be sleeping` 警告，保留跟踪。
此次没有复测声音、笔、蓝牙配件，也没有长时间测量休眠电流；单次成功不能关闭
全部待机/唤醒待办。临时显示恢复定时器和唤醒定时器均已清理或自动回收。

## 关机对照：拔线正常，USB 供电进入 U-Boot 充电等待

最初用户报告 Linux 关机会重启，插电/拔线状态记忆不确定。本轮使用同一已运行
系统直接执行 `systemctl poweroff`，没有刷写、改内核参数、改 PMIC 或切换系统。

| 场景 | 执行前 | 观察结果 |
| --- | --- | --- |
| 拔线 | USB / 无线供电均 offline，电池 56%，RTC 闹钟为空 | 持续关闭，没有自行亮起；用户需长按电源重新开机 |
| 接电脑 USB | USB online，电池 55%，保持登录界面 | 关机后进入 U-Boot，显示类似 charging / Press POWER to boot 的提示；按电源继续正常启动 |

两次重新进入系统后均仍为原系统路径，失败服务为 0；B 槽成功标志已设置。
用户最初将提示描述为重启过多，后修正为 Exit/控制台，最终确认存在充电/按电源
启动提示。因此撤回启动失败计数异常的推断，不重置槽位、不反复关机重试。
持久 journal 记录了服务停止与卸载过程；journal 停止后无末尾日志不证明 panic。
拔线日志中有 `/nix: target is busy` 卸载提示，设备仍保持关闭，不能据此认定它导致重启。

### 与实际 U-Boot 源码对照

锁定源 `SushyDev/u-boot` 的 `7025b792e2884c5fb4747d891e30002ea029048a`，
`board/qualcomm/sheng/sheng.c` 的 `sheng_charger_boot_poweroff()`：

- 读取已有 PBS power-on reason，匹配 charger-initiated + cold boot；
- 显示 `sheng: charging. Press POWER to boot.`，等待按电源后继续菜单；
- 注释说明此前关机后插电再次启动造成循环，因此采用停留等待作为过渡；
- 同时明确 U-Boot idle 不是真正的低功耗充电模式。

本机已下载的 PR #4 双系统 CI boot.img 与当前 `boot_b` 前同长度内容 SHA256 一致：
`b9bf7df5172e007a0caef5b0243862812dd0d9bf7ec0226185bca3abdee839a6`。
这是 boot.img 内容范围的核验，不是含尾部填充的整个 boot 分区哈希。
设备 DT 中还保留 `chosen/sheng,pon` 与 `chosen/sheng,xbl-log` 诊断属性；原始日志
只留私有证据目录。手动按电源之后取得的 PON 值不能冒充最初 USB 启动时的原始值。

源码、镜像内容核验与用户最终确认的屏幕提示相符：本次 USB 场景命中了已有
充电启动等待逻辑，而非正常 Linux 桌面自动启动或 A/B 槽启动失败保护。
不能外推到其他固件、其他充电器或所有 Linux 发行版。

### 已有充电程序与缺口

仓库已打包 Debian 的 `xiaomi-charger-mode`，其服务要求
`androidboot.mode=charger`。当前正常 NixOS 启动参数无此标志，服务按条件跳过。
仅有程序和 unit 不证明已打通离线充电；此次未强制启动该程序。

当前可用方式是先拔 USB 再正常关机。插电后的完善方向应先对照 Debian/原厂的
启动模式传递和充电程序行为，评估专用充电启动路径及实际功耗、温度、拔线退出、
按键进入系统等，再决定是否替代 U-Boot 等待。不能盲目传播模式标志或循环调用
poweroff，也不能仅关闭背光便宣称完成低功耗关机充电。

EFI 不是关机或离线充电的前置条件。后续对 bootloader 的任何修改仍需原启动路径、
临时启动/恢复以及单/双系统回归。原厂快充充电器场景、本轮正常登录后从桌面菜单
发起的关机、长期关闭状态耗电仍未单独验收。


## 后续 USB 挂起恢复与模式对照

同一 7.3.0 / Niri / tmpfs 系统，连接电脑 USB：

| 测试 | 实际挂起时间（BOOTTIME 与 MONOTONIC 增量之差） | 结果 |
| --- | --- | --- |
| deep 恢复检查第 1 轮 | 0.930 秒 | 提前唤醒，未等到 35 秒定时器 |
| deep 恢复检查第 2 轮 | 2.580 秒 | 提前唤醒，未等到 35 秒定时器 |
| deep 独立事件跟踪 | 3.830 秒 | 提前唤醒；记录了电池管理消息链路 |
| 临时 s2idle 对照 | 35.547 秒 | 等到定时器恢复；同一 boot ID |

所有测试均有计数增加且 fail 为 0，但前三项**不算稳定待机通过**。
前两轮恢复后 NetworkManager / Bluetooth 与用户 PipeWire / Pulse / WirePlumber
均 active，默认 Speakers 保留；蓝牙已连接设备数前后为 1，不等于笔压感或蓝牙
音频已经复验。s2idle 唤醒后的屏幕、触摸与两秒 PipeWire 提示音由用户确认正常。

跟踪使用独立 tracefs instance（power suspend/resume、wakeup source、IRQ entry），
没有覆盖全局跟踪设置；采集完成后删除实例。machine_suspend 返回后，首先观察到
`ipcc_0`（该次 IRQ 13）、`glink-smem`（该次 IRQ 240），随后是
`qcom-battmgr-bat` wakeup_source_activate。IRQ 编号不能写成跨启动固定值。
该顺序指向电池/充电消息相关链路，但不单凭事件先后宣称完整根因已修复。
锁定源码 `drivers/mailbox/qcom-ipcc.c` 使用 IRQF_NO_SUSPEND；
`drivers/power/supply/qcom_battmgr.c` 处理 PMIC GLINK 电池通知。

没有停用电池、传感器、蓝牙或屏蔽 IRQ。s2idle 只作运行时单变量对照，trap 已恢复
原 deep；没有更改个人配置、仓库默认、swap、内核或 bootloader。
下一步是电池供电下更长的 s2idle 对照和功耗口径校准；之后才评估个人主机的候选
默认模式，不能由短测结果直接更改所有 sheng 镜像。

`charge_counter` 是相对电荷计数，按 Linux ABI 应为 µAh，不要求与 charge_full
具有相同零点。读到约 5227、charge_full 为 9571000，**不能仅凭二者比例判断驱动错误**。
需结合时间差和电流读数核对固件上报的实际单位/精度；本轮暂不由其计算精确续航。


### 拔线 s2idle 三分钟与个人配置候选

拔线（USB offline）后，同一 boot ID 下临时 s2idle 实际挂起约 180.577 秒，
按定时器自动恢复；success 4→5、fail 保持 0。用户确认解锁、Niri 桌面、触摸正常。
capacity 前后均 55，charge_counter 前后均 5223，温度均约 21.6°C。
读数不变可能受精度或更新周期影响，不能据此宣称零耗电或给出精确待机续航。
恢复后 SSH 可用、失败服务为 0，已恢复运行时 deep，测试定时器和独立跟踪均已清理。

个人 `nix-config` 仅在 sheng 主机增加候选参数：

```nix
boot.kernelParams = [ "mem_sleep_default=s2idle" ];
```

本地提交 `78eecc9`（fix(hosts/sheng): select s2idle for suspend），未推送、未部署。
参数求值和 dry-build 通过；x86 主机预览因缺少 ARM 缓存列出内核与大量应用派生项，
没有开始实际构建。部署前应核对实机缓存或使用 ARM CI，保留原 deep 可用世代并验证
新世代启动/回退及更长时间待机。仓库通用镜像默认未改，不能将该候选写成已激活修复。

### 2026-11-09：s2idle 候选部署与验证

s2idle 候选已部署到设备（提交 `78eecc9`，设备端 nix-config 仓库，已推送远程）：

- 设备端真实配置：`/home/fall_dust/Documents/nixconf`（非 `/etc/nixos/nixconf`，后者为过时副本已删除）
- 构建方式：设备本地 nix store 已有 7.3.0 内核缓存，`nixos-rebuild boot` 直接构建，未编译内核
- 新世代：`/nix/store/4wh251jyy5a3fm9h7cngdpc2rjrk4abx-nixos-system-sheng-26.11.20261103.1d06008`，旧世代保留可回退
- 重启后验证：`/sys/power/mem_sleep` 显示 `[s2idle] deep`，失败服务 0，kernel cmdline 含 `mem_sleep_default=s2idle`
- 30 秒挂起/唤醒：通过（USB 供电）
- 5 分钟挂起/唤醒：通过（USB 供电）

**拔线挂起测试被阻塞：** 设备断开 USB/拓展坞供电后尝试 s2idle 挂起，DWC3 USB 控制器
`__dwc3_set_mode` 工作队列卡死（125s+），`events_freezable` 无法冻结，内核拒绝 suspend。
重启后也立即复现，断开蓝牙笔无效。这是内核级 bug（M02 上游补丁范畴），与 s2idle 候选无关。
用户手动触发挂起导致桌面冻结，需长按电源重启恢复。

**结论：** s2idle 候选稳定性和唤醒已验证（两次 USB 供电测试通过），可作为长期默认。
拔线耗电数据因 DWC3 问题无法采集。仓库通用镜像默认未改。

## 2026-11-13：7.3.4 唤醒后再次挂起

第 16 世代运行 `7.3.4-sm8550`，使用 s2idle。接线和拔线测试均出现唤醒后短暂显示。
上一轮启动日志记录短按电源键唤醒，随后 Niri 进程再次向 logind 请求 suspend。
`HandlePowerKey=ignore` 已生效。该记录没有出现原先的 DWC3 work item 阻塞，
也不足以确认随后重启的触发源。DWC3 补丁保留待独立对照。

禁用 Niri 内置电源键处理后，拔线从 Noctalia 菜单触发 s2idle。
22:03:30 进入挂起，22:04:05 短按电源键恢复，未立即再次挂起。
用户确认画面保持正常，但直接回到桌面。本次验证覆盖唤醒，锁屏仍待验证。

第 18 世代继续使用 `7.3.4-sm8550`。sheng 通过声明式 Niri 配置禁用内置电源键挂起，
Noctalia 菜单使用 `lock_and_suspend`。22:49:04 确认会话锁定，22:49:06 进入
s2idle，22:49:16 唤醒，22:49:23 解锁。用户确认挂起和唤醒正常。
