# sheng 外设实机验证

[English](./peripheral-validation.en.md) · 简体中文

测试环境：独立 `linux` 根分区、B 槽 NixOS、内核 7.3.0、NixOS 26.11，
硬件模块与单系统共用。以下是实际验证范围，不代表所有桌面应用已经测试。

| 项目 | 结果及范围 |
| --- | --- |
| 启动与更新 | 标准 rebuild、候选世代重启、回退和 Android/NixOS 双向切换均已验证。 |
| 存储 | linux 根分区扩容成功；切换系统后两边测试文件保留。 |
| 网络与 USB 调试 | Wi-Fi/SSH、Linux ACM 串口、Recovery/Android ADB 已使用；不等于 USB host、DP 或蓝牙音频已验证。 |
| ADSP 与电量 | ADSP 正常运行，电量可读，关键厂商服务可启动；没有由此推断最高充电功率。 |
| 传感器 | 加速度计/环境光在发现结束后报告可用；桌面自动旋转策略、所有读数精度尚未系统测试。 |
| 屏幕 | 命令行显示正常；DRM 可列出 144/120/90/60/50/48/30 Hz，已临时切换到 120 Hz。 |
| 触摸 | 已采集多点触摸、坐标变化及接触/释放事件。 |
| 原装键盘 | 已采集 8 次 Shift 按下及释放；本次实物为不带触控板版本，触控板未测。 |
| 扬声器 | ALSA 48 kHz、16 bit、双声道播放成功，用户确认听到提示音。 |
| 麦克风 | 两秒双声道采集成功，电平非零；没有保存录音，不等于所有麦克风路由已测试。 |
| 主摄与前摄 | libcamera 0.7.2 分别收到三帧 ABGR8888 彩色数据；未保存画面。 |
| 副摄 ov02b1b | 收到三帧 R10_CSI2P 原始 Bayer 数据；CPU 去马赛克仍不支持该格式，不能据此宣称桌面彩色预览可用。 |
| 焦点触控笔 | 120 Hz 下坐标、倾角、悬停、落笔、按键和 0～8057 压力变化已测；详见下节。 |
| 指纹 | 录入成功、同一手指匹配成功、未录入手指拒绝；测试指纹已删除，确认没有残留录入记录。 |

2026-11-13 社区反馈原装键盘背光：`/sys/class/leds/*kbd*/brightness` 为
`root:root 0644`，`max_brightness=100`，root 写入 100 可以点亮。
候选规则在 LED 注册时将 `brightness` 设为 `root:video 0664`。
待实机重启后核对权限、验证 `video` 组用户写入，再用 `evtest` 检查背光键
并验证桌面是否响应。

## 焦点触控笔

2026-11-07 补测用户 Niri 配置：原生 3048×2032、120 Hz 下采集到
悬停、坐标、倾角、落笔/抬笔、按键及 0～6703 压力变化。
`nix-config` 的 `211bf39` 固定 ARM Niri 的 DSI-1 为 120 Hz；
锁定板级提交 `3388dcb` 后通过 rebuild boot 部署并重启，Niri 读回仍为 120 Hz。
运行系统为 `/nix/store/z5x00wzanv43xvcm2agc5agwmfbpg25z-nixos-system-sheng-26.11.20261103.1d06008`。
这次验证输入事件和重启后的显示模式，尚未验证绘画应用中的笔刷或防误触。

采用 Debian-sheng 所用的 THP 和笔状态程序。THP 上游注明笔扫描支持 60 Hz 和
120 Hz；144 Hz 下不能把“没有笔输入”视为已排除的软件故障。
桌面中应先选择 60/120 Hz，再测试落笔与压感。

本轮在 120 Hz 和蓝牙连接完成后，实测焦点触控笔的落笔/抬笔、笔按键、坐标、
悬停和倾角，压力值范围为 0～8057。配对状态为 Paired/Bonded/Trusted/Connected。
临时测试结束后已恢复原 144 Hz 命令行模式，永久配置没有改变。

笔坐标、倾角和悬停来自触摸数据，压感依赖蓝牙 HID。只看到笔靠近时的坐标变化，
不等于落笔、压感已正常。侧边吸附电量读取也不代表蓝牙配对完成。

纯命令行镜像没有桌面的蓝牙认证代理。首次配对可使用系统已有工具：

1. 把笔吸附在侧边，运行 `xiaomi-pen-status-cli --json` 读取当前笔地址。
2. 运行 `bluetoothctl --agent NoInputNoOutput`，在其交互界面执行：

   ```text
   default-agent
   scan le
   ```

3. 等目标地址出现，再依次执行；把 `<笔地址>` 替换为第 1 步检测到的地址：

   ```text
   pair <笔地址>
   trust <笔地址>
   connect <笔地址>
   info <笔地址>
   scan off
   quit
   ```

4. 确认 `Paired: yes` 和 `Connected: yes` 后再取下笔。首次配对期间保持吸附。

桌面会话中使用 `xiaomi-pen-status` 的自动配对辅助，并确保该桌面的蓝牙代理正在运行。
`No agent available` 属于认证代理缺失，不能据此判断笔硬件不支持。
Android 与 NixOS 的配对数据库各自独立，本轮没有实现两边配对密钥自动同步。

参考：[THP](https://github.com/ianchb/xiaomi-sheng-thp)、
[笔状态程序](https://github.com/ianchb/xiaomi-pen-status)。

## 指纹测试注意事项

本次 FPC1553 的 fprintd 报告 38 个录入阶段。阶段数不等于手指触碰次数，
应以 `enroll-completed` 判断完成；不要按固定次数推断录入已经结束。
指纹录入、正确手指匹配、错误手指拒绝和删除后的状态需要分别确认。
测试日志只记录操作结果，不导出指纹模板。

长时间保持录入/验证采集曾触发 libfprint 的“防止过热”保护；停止采集并冷却后，
匹配和拒绝测试均完成。没有修改温控策略。触发保护时的 `verify-disconnected`
不能记作指纹不匹配，也不能记作验证通过。

## 尚未确认的项目

2026-11-07 在线切换时的充电认证超时已定位：电脑供电为 SDP，程序在
检查无认证 PDO 前写入 Type-C `data_role=host`，同步 sysfs 写入约 21 秒才返回，
超过服务 20 秒限制。`ba47c5d` 将已有 PDO 检查移到角色切换前。
实机修正版连续启动两次均约 2 秒正常退出；正式打包后配置激活 test、switch
以及再次手动重启服务均通过，失败服务数为 0。运行系统为
`/nix/store/v8njih6prk2f3b6cv5yvdsc0ghflp9ql-nixos-system-sheng-26.11.20261103.1d06008`。
这验证普通电脑 USB 供电下的跳过路径，不代表原装充电器认证或 120 W 功率已验收。

- 桌面登录/锁屏、屏幕键盘、触摸映射、旋转策略与绘画应用。
- 挂起/唤醒、长时间稳定性、续航、120 W 充电功率及关机充电体验。
- 笔在重启/休眠后的持久重连、跨 Android 配对关系，以及焦点触控笔 Pro。
- 原装键盘折叠停用、麦克风指示灯；没有触控板版本实物可测。
- PipeWire 路由、全部麦克风和扬声器声道、蓝牙音频、USB 扩展坞/外屏。

这些项目按 [TODO](../TODO.md) 的验收标准推进。Android OTA 自动化已按用户决定排除，
后续采用 [选择性重刷 Android](dual-boot.md#android-维护策略选择性重刷)。

## 2026-11-08：普通用户 PipeWire 补测与桌面镜像边界

个人 Niri 系统 `/nix/store/v6sdp26sdgnffxcrk2pgdriapf9syd10-nixos-system-sheng-26.11.20261103.1d06008`
中，普通用户的 PipeWire 1.6.9、pipewire-pulse、WirePlumber 0.5.19 均为 active。
默认输出为 `alsa_output.platform-sound.playback.0.0`（Speakers，FL/FR）；
通过 `pw-play` 播放约两秒轻提示音成功，用户确认听到。没有采集或保存用户音频。
此项补充了此前仅 ALSA 直放的证据，仍不代表蓝牙音频、所有输入/输出路由均已验证。

另一个用户的旧 KDE 镜像日志显示 `/run/user/0` 和 `ConditionUser=!root`，
确认该次声音服务连接失败来自 root 会话。PR #4 为四种桌面镜像增加普通用户
`nixos`；ARM CI 构建通过。双系统 KDE CI 产物经本地只读解包检查，SDDM 配置为
`User=nixos`、`Session=plasma.desktop`，用户声明为非系统用户，两个 PipeWire socket
均加入 `sockets.target.wants`，root 条件未被绕过。
该镜像的内核、DTB 和 PipeWire store 路径与上述已运行的版本一致，但此检查没有
启动该 KDE 镜像，不能替代其桌面登录及扬声器实听。GNOME 镜像也未作实机验收。

反馈桌面无声音时，在桌面内以普通用户执行（不要加 sudo），并提供镜像/CI 版本、
单/双系统模式及以下输出：

```sh
whoami
readlink -f /run/current-system
systemctl --user status pipewire pipewire.socket pipewire-pulse wireplumber --no-pager -l
journalctl --user -u pipewire -u pipewire-pulse -u wireplumber -b --no-pager -n 100
wpctl status
```

应分别区分“无法连接声音服务”“没有检测到输出设备”“已有输出但播放无声”。
不要仅凭音量图标判断内核声卡或扬声器驱动损坏；公开日志前检查并隐去个人信息。


## 2026-11-09：挂起到内存的范围

这里测试 suspend，不是需要磁盘恢复配置的 hibernate。一次拔线 deep 挂起约
40.718 秒并自动恢复，用户确认显示/触摸正常。接电脑 USB 的后续三次 deep 则仅
挂起约 0.930 / 2.580 / 3.830 秒，虽无 fail 计数也不能认定稳定待机通过。
临时 s2idle 对照约 35.547 秒等到定时器恢复，用户确认显示、触摸和 PipeWire
提示音；已恢复原 deep 设置。网络和用户音频服务 active；蓝牙连接数量恢复不
代表已复验笔或蓝牙音频。详见 [功耗与挂起记录](power-validation.md)。
