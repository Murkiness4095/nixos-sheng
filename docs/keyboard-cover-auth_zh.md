# sheng 官方键盘盖认证链路（Nanosic WN8030 + xiaomi_devauth）

## 现象

- 官方键盘盖（Xiaomi Pad 6S Pro 12.4 Touchpad Keyboard）输入有延迟，并会
  隔一段时间整段卡住不动，恢复后补出一批按键。
- `dmesg` 每约 60 秒出现一次：

```text
nanosic_wn8030 2-004c: timeout waiting for keyboard auth token
```

- 认证守护进程 `sheng-devauth` 被反复重启：单次开机 30 分钟内
  `grep -c Stopping` = 386，而 `grep -c 'Main process exited'` 只有 12。

## 链路

键盘盖走 **I²C HID**，不是 USB（因此 USB autosuspend 规则与它无关）：

```text
官方键盘盖（pogo 触点）
  → i2c-2 0x4c  nanosic_wn8030        (drivers/hid/hid-nanosic-wn8030.c)
  → /dev/nanosic_auth                (misc 设备，用户态必须 open，否则驱动不发认证初始化)
  → xiaomi_devauth                   (nixos/hardware/xiaomi-sheng/sensors/devauth.nix, 预编译 blob)
  → QTEE listener service ID 0x2000  (RPMB，单持有者)
```

驱动侧行为（`DotRedstone/linux-sheng`，本仓库只固定 revision）：

- 用户态没有 open `/dev/nanosic_auth` 时，驱动收到键盘的 `0x24` 认证请求**不会**
  发起认证（`if (nanosic->auth_open) xm_auth_init()`）。
- 收到键盘的 `kb auth s3t1`（UID + challenge）后，驱动在**线程化中断**里执行
  `wait_for_completion_interruptible_timeout(..., msecs_to_jiffies(5000))`，
  等用户态通过 `write(/dev/nanosic_auth)` 回写 16 字节 token。
- 键盘数据同样在这条 handler 里通过 I²C 读取，所以这 5 秒内**输入完全停止**
  （表现为"卡住不动"），恢复后补发（表现为"延迟"）。
- 超时只打印 `timeout waiting for keyboard auth token`，不走 `xm_auth_s5t1`
  （不回写 token），键盘固件约 60 秒后重发 `0x64` 重试 → 周期性卡顿。

## 根因

QTEE 的 listener service **0x2000（RPMB）同一时刻只允许一个注册者**。同一份
Qualcomm RPMB service 实现有三份副本在争这个槽位：

| 持有者 | 来源 | 持有方式 |
|---|---|---|
| `qteesupplicant` | 指纹包 `lib/qtee-listeners/librpmbservice.so` | 开机注册，永不释放 |
| `libfpc1553-qtee.so` | 指纹包静态链接 `prebuilt/aarch64/build-libs/librpmbservice.a` | 指纹操作时按需注册 |
| `xiaomi_devauth` | Xiaomi 预编译 blob | 每次认证按需注册，用完即 deinit |

先注册者赢，后注册者得到
`IRegisterListenerCBO_register(8192) failed: 0xffffff9d`（8192 = 0x2000）。
`xiaomi_devauth` 把这个失败当作致命错误，直接 `exit 255`，因此 token 永远
写不回内核，键盘认证永远无法完成。

设备侧验证（临时停掉指纹链路后）：

```text
[RPMB] RPMB_INFO: RPMB service initialized successfully with service ID: 8192
[RPMB] RPMB_INFO: RPMB dispatch: cmd_id=258 (0x102), buf_len=20480
Sent pad token to kernel driver!
```

## 修复

`nixos/packages/xiaomi-sheng-fingerprint.nix`：把 supplicant 的 RPMB listener
插件替换成 stub。stub 只满足 `qteesupplicant` 的 `dlopen()` + `dlsym("init"/"deinit")`
契约，**不注册**服务；两个按需注册的客户端（`xiaomi_devauth`、
`libfpc1553-qtee.so`）此后可以正常拿到槽位。

两个被否掉的方案，原因写在这里以免重复踩：

- **调整 systemd 启动顺序**：`xiaomi_devauth` 每次认证注册后立即 deinit（短暂持有），
  而 supplicant 开机永久持有，任何启动顺序都无法让 `xiaomi_devauth` 持续可用。
- **直接删除 `librpmbservice.so.1`**：supplicant 里是硬编码的
  `libtimeservice.so.1` / `libfsservice.so.1` / `libgpfsservice.so.1` /
  `librpmbservice.so.1` 列表，逐个 `dlopen(..., RTLD_NOW)`；加载失败会走到
  `ERROR: listeners registration failed`，大概率直接退出（该 unit 是
  `Restart=always`，会变成重启循环）。保留同名 stub 可以完全绕开这条失败路径。

## 验证

```sh
# 1) 认证不再超时（数值应停止增长）
dmesg | grep -c 'timeout waiting for keyboard auth token'

# 2) devauth 不再因 RPMB 退出
journalctl -b -u sheng-devauth --no-pager | grep -E 'RPMB|Sent pad token|status=255' | tail -20

# 3) supplicant 仍正常，且不再占坑
systemctl status qteesupplicant --no-pager | head -8
journalctl -b -u qteesupplicant --no-pager | tail -20
#    期望：没有 dlopen 失败；没有 "RPMB service registered (service ID: 0x2000)"

# 4) 关键回归点：指纹仍可录入/验证
fprintd-list "$USER"
fprintd-verify "$USER"
```

状态：以上第 1 至 3 项来自本轮的诊断结论（停掉 supplicant 可复现"认证成功"），
stub 版本本身尚未在设备上验证；第 4 项是本次改动的主要风险点。

## 回滚

改动集中在一个文件的两处：删除 installPhase 里的 `case` 分支（恢复安装原插件）、
删除 `qteeRpmbStub` 定义。回滚后键盘认证会恢复为"永不成功"的状态。

## 残留问题

1. `sheng-devauth` 每约 5 秒被外部 stop 一次（`Stopping` 386 次 vs
   `Main process exited` 12 次）。已确认不是 udev 规则触发（idle 时
   `udevadm monitor --subsystem-match=hid` 无事件），归因待查。该行为会让
   devauth 反复丢失 `/dev/nanosic_auth` 的 fd，进一步放大键盘卡顿。
2. 驱动在线程化中断里阻塞 5 秒等待 token 属于设计缺陷：认证失败不应阻塞输入
   路径。这条需要上游 `DotRedstone/linux-sheng` 修改，产物是 boot image
   （刷 `boot_b`），本仓库只能固定 revision。
