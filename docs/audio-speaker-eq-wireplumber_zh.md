# 扬声器 EQ 组件类型错误导致整机无声

[English](audio-speaker-eq-wireplumber.md) | [简体中文](audio-speaker-eq-wireplumber_zh.md)

本文档记录 sheng 移植中一次「内核、UCM、功放全部正常，但 PipeWire 里一点声音都没有」
的故障：WirePlumber 因为扬声器 EQ 的 filter-chain 组件加载失败而整体退出。

## 现象

刷入某一版 niri rootfs 后，播放视频、音乐完全没有声音，音量条和音量控制都正常。

```sh
wpctl status
# Audio → Sinks: 只有一个 "虚拟输出"（auto_null），没有任何 ALSA 设备

systemctl --user status wireplumber
# failed (Result: start-limit-hit)
# Process: ExecStart=.../bin/wireplumber (code=exited, status=78)
```

硬件侧一切正常，这也是判断故障域的关键证据：

```sh
aplay -l
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 0: MultiMedia1 Playback
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 1: MultiMedia2 Playback
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 2: MultiMedia3 Capture

speaker-test -D hw:0,0 -c 2 -t sine -l 1   # 有声音
```

`speaker-test -D hw:0,0` 出声说明 stage-1 内核模块、ADSP 固件、UCM 路由和 6 路
WSA 功放使能全部正常，问题只在用户态。

## 根因

`nixos/configuration.nix` 中 `92-sheng-speaker-eq` 把 filter-chain 声明为：

```nix
{
  name = "libpipewire-module-filter-chain";
  type = "pw-module";        # 错误
  arguments = { ... };
  provides = "filter.sink.sheng-speaker-eq";
}
```

`type = "pw-module"` 表示把它加载进 **WirePlumber 自己的主 `pw_context`**，而主
context 的配置只加载三个模块（`share/wireplumber/wireplumber.conf`）：

```json
context.modules = [
  { name = libpipewire-module-rt ... },
  { name = libpipewire-module-protocol-native },
  { name = libpipewire-module-metadata }
]
```

里面**没有 `libpipewire-module-adapter`**，所以没有 `adapter` factory。而
module-filter-chain 用两个 `pw_stream` 建节点，`pw_stream_connect()` 里：

```c
/* src/pipewire/stream.c:2199-2203 */
factory = pw_context_find_factory(impl->context, "adapter");
if (factory == NULL) {
    pw_log_error("%p: no adapter factory found", stream);
    res = -ENOENT;
    goto error_node;
}
```

于是模块初始化失败，WirePlumber 日志：

```
pw.stream: ...: no adapter factory found
pw.stream: ...: can't make node: No such file or directory
failed to load components: failed to load required component 'filter.sink.sheng-speaker-eq
  [pw-module: libpipewire-module-filter-chain]': Failed to load pipewire module ...: No such file or directory
systemd: wireplumber.service: Main process exited, code=exited, status=78/CONFIG
```

该组件在 profile 里是 `required`，所以 WirePlumber 直接退出，重试 5 次后
`start-limit-hit`。会话管理器没了 → ALSA monitor 不会创建任何节点 → 系统里只剩
`auto_null` → 任何播放都是静音。

## 触发条件（为什么之前几次刷机有声音）

`be0a805`（2026-07-26）引入这段配置后一直没改过，出问题的是 nixpkgs 升级：
`8068eb8`（2026-09-23）把 nixpkgs 从 2026-06-10 换到 2026-09-22，随之
wireplumber 0.5.14 → 0.5.17、pipewire 1.6.5 → 1.6.8。同一份配置在两套版本上的实测：

| nixpkgs | wireplumber / pipewire | `type = "pw-module"` 的结果 |
| --- | --- | --- |
| `9ae611a4`（2026-06-10） | 0.5.14 / 1.6.5 | 正常：filter-chain 节点建立，WirePlumber 存活 |
| `6774f7bc`（2026-09-22） | 0.5.17 / 1.6.8 | 失败：`no adapter factory found`，exit 78 |

原因是 WirePlumber 的组件类型语义变了。0.5.14 的 `components_and_profiles` 文档里
**没有 `pw-module-client`**，只有 `pw-module`；0.5.17 拆成两种：

- `pw-module` — 「loaded in WirePlumber's main `pw_context` … what protocol extensions
  and object factories need」；
- `pw-module-client` — 「loaded in the *client context* … **This is the right type for
  modules that process media, such as `libpipewire-module-loopback`,
  `libpipewire-module-filter-chain` and `libpipewire-module-combine-stream`**」。

上游自带的 `smart-equalizer.conf` 样例用的就是 `pw-module-client`。

## 修复

`c0bcbac`：把 `type` 改成 `pw-module-client`。client context 由 PipeWire 的
`client.conf` 创建，而该文件会加载 adapter 模块：

```
share/pipewire/client.conf:78
    { name = libpipewire-module-adapter
```

## 不重建、不刷机的应急处理

已经刷进设备、还能 SSH/ADB 进去的情况下，可以只用用户级配置先把声音找回来。
WirePlumber 会读 `$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d/*.conf`：

```sh
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cat > ~/.config/wireplumber/wireplumber.conf.d/99-sheng-eq-fix.conf <<'EOF'
wireplumber.profiles = { main = { "filter.sink.sheng-speaker-eq" = disabled } }
EOF
systemctl --user restart wireplumber
wpctl status        # Sinks 里应出现 alsa_output.platform-sound.HiFi__Speaker__sink
```

代价是没有扬声器 EQ（声音正常，只是未调音）。注意两点：

- **不能用重新定义 `wireplumber.components` 的方式覆盖**：实测这个数组不会替换系统
  里那一份，坏组件照旧被加载；只有 `wireplumber.profiles` 这类标量覆盖才生效。
- 想同时保留 EQ，可以在用户配置里禁用原组件、再以新名字（例如
  `sheng.speaker-eq-fixed`）加一个 `type = "pw-module-client"` 的同参数组件并把
  它标成 `required`，实测 filter-chain 节点能正常建立。

更彻底的两条路（都不需要刷 `boot_b`）：

```sh
# 设备内只更新 stage-2（仓库用你刷的那个镜像对应的 remote/分支）
git clone <nixos-sheng 仓库地址> ~/nixos-sheng
cd ~/nixos-sheng && git checkout <对应镜像的分支>
sudo sheng-nixos-rebuild "$PWD/nixos#sheng-niri"
# 成功后记得删掉应急 drop-in，否则 EQ 继续被禁用：
rm ~/.config/wireplumber/wireplumber.conf.d/99-sheng-eq-fix.conf && systemctl --user restart wireplumber
```

或者直接用 CI 构建、含修复的 rootfs 镜像刷 `linux` 分区（家目录会被重置，drop-in
一并消失）。

## 离线复现（不需要设备）

用 `nixos/configuration.nix` 真实生成的 conf.d 起私有 PipeWire/WirePlumber 实例即可
复现和验证：

```sh
# 1. 取出 NixOS 生成的配置（键值即为 conf.d 文件内容）
nix eval --json --impure --expr '
  let f = builtins.getFlake "/path/to/nixos-sheng/nixos";
      s = f.nixosConfigurations.sheng-niri;
  in s.config.services.pipewire.wireplumber.extraConfig."92-sheng-speaker-eq"' \
  | jq -r 'to_entries[] | "\(.key) = \(.value|tojson)"' > eq.conf

# 2. 私有运行目录 + 私有 XDG_CONFIG_HOME
mkdir -p /tmp/wp/runtime /tmp/wp/config/wireplumber/wireplumber.conf.d
cp eq.conf /tmp/wp/config/wireplumber/wireplumber.conf.d/92-sheng-speaker-eq.conf
export XDG_RUNTIME_DIR=/tmp/wp/runtime XDG_CONFIG_HOME=/tmp/wp/config

pipewire & sleep 3; wireplumber & sleep 6
wpctl status
```

`pw-module` 会得到 exit 78 和上面那段报错，`pw-module-client` 会得到：

```
Filters:
  - filter-chain-…
    … input.filter.sink.sheng-speaker-eq     [Audio/Sink]
    … output.filter.sink.sheng-speaker-eq    [Stream/Output/Audio]
```

再造一个与 `filter.smart.target` 同名的假 sink，可以进一步确认 smart filter 真的挂到了
目标设备上：

```sh
pw-cli create-node adapter '{ factory.name=support.null-audio-sink \
  node.name=alsa_output.platform-sound.HiFi__Speaker__sink \
  node.description="Fake Speaker" media.class=Audio/Sink object.linger=true \
  audio.position=[ FL FR ] }'
pw-link -l | grep -A2 filter.sink.sheng-speaker-eq
# output.filter.sink.sheng-speaker-eq:output_FL |-> alsa_output...:playback_FL
```

## 诊断命令速查

```sh
aplay -l; arecord -l; cat /proc/asound/cards
wpctl status
systemctl --user status pipewire pipewire-pulse wireplumber --no-pager
journalctl --user -u wireplumber -b --no-pager | tail -80
speaker-test -D hw:0,0 -c 2 -t sine -l 1        # 绕过用户态，直接打 ALSA
```

判读：`speaker-test` 有声而 `wpctl` 里没有 sink → 用户态问题，先看 wireplumber
是否 failed；`speaker-test` 也无声 → 查模块加载（`sheng-audio-modules.service` 的
`modprobe ... || true` 会静默吞掉失败）、UCM 名称匹配与功放使能。

## 边界

- 该故障只影响 stage-2（rootfs）；不涉及 kernel、DTB、initrd 或 boot cmdline，
  因此不需要刷 `boot_b`。
- 回滚：`git revert c0bcbac`。
