# Debian-sheng 适配参考

设备功能优先参考 [ianchb/debian-sheng](https://github.com/ianchb/debian-sheng)。
已有方案先核对其实际构建脚本、release 包内容、服务和桌面集成，再移植为 Nix 包和模块。
Debian 没有覆盖的功能或已实测的问题，才增加独立实现或修复。

本轮参考提交：`da1d2761dbc1ccaea0122f8b0c2dce2d52edaeb2`。

| 组件 | 选择及差异 |
| --- | --- |
| 内核 | `sheng-7.3.0`，使用上述 Debian 提交的 `sm8550.config`，保留本项目的 NixOS/调试配置片段。 |
| FastRPC | 与 Debian 一致使用 1.0.2；NixOS 将可写传感器注册表放在 `/var/lib/qcom`，并修复相应搜索路径。 |
| libssc | 固定 Debian 所跟踪上游当前提交，版本 0.4.4，保留 QMI 服务等待补丁。 |
| iio-sensor-proxy | 与 Debian 一致使用 3.9 的上游 SSC 支持；保留 sheng 的设备发现、早期客户端声明和可用性通知修复。 |
| 触摸及笔输入 | 与 Debian 的 release 一致使用 `xiaomi-sheng-thp` v0.3.9，经 uinput 提供输入设备。 |
| 笔状态 | 与 Debian 的 release 一致使用 `xiaomi-pen-status` v0.2.3，提供电量、连接状态和蓝牙配对辅助。保留原有独立 CLI 作为兼容命令。 |
| 桌面自启动 | 笔状态程序沿用 Debian 包的 XDG 自启动行为，不额外排除 GNOME。 |

手写笔输入与笔状态程序是两个组件。安装电量托盘程序不能替代 THP 输入处理。
THP 上游注明笔扫描支持面板的 60 Hz 和 120 Hz 模式；不得据此宣称 144 Hz 也支持笔输入。

系统依赖继续跟踪 `nixos-unstable`，但设备组件优先选择 Debian 使用的版本。
因此“更新系统依赖”不意味着将 FastRPC 等设备组件无条件改成开发分支 HEAD。
U-Boot 使用兼容的 Zig 0.15.2；指纹后端的 libfprint 基础版本由其补丁要求固定。

## 验证

CI 构建完整设备用户态、内核、两个个人配置模板和 rootfs。
模板使用各自提交的锁文件构建，生成的系统路径必须与镜像的系统路径相同。
CI 同时导出系统闭包、系统路径、内核路径、DTB 路径、源提交和锁文件，供设备更新及对照。

构建通过不能代替实机测试。设备运行的系统必须与 CI 导出路径核对，并检查实际启动、
网络、USB 控制通道、ADSP、传感器及服务状态。未实测的外设和桌面交互应单独标记。
