# 开发与排障

[English](./DEVELOPMENT.md) · 简体中文

本文为中文导读。完整命令和证据见[英文原文](./DEVELOPMENT.md)。

优先通过 SSH 或 Linux USB gadget 串口获取设备状态。启动问题先检查 `/chosen`、U-Boot 黑盒和启动耗时，再决定是否构建调试镜像。Linux USB 串口在内核启动后才出现。黑屏时应同时检查系统是否上线。双系统设备请使用双系统指南中的维护路径。

[维护交接](HANDOVER.md) · [双系统指南](dual-boot.md)
