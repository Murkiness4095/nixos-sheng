# Speaker EQ component type breaks WirePlumber and mutes the whole system

[English](audio-speaker-eq-wireplumber.md) | [简体中文](audio-speaker-eq-wireplumber_zh.md)

This document records a sheng bring-up failure where the kernel, the UCM routing, and
the speaker amplifiers were all healthy, yet PipeWire produced no sound at all: the
speaker-EQ filter-chain component failed to load and took WirePlumber down with it.

## Symptom

After flashing one particular niri rootfs build, video and music playback were completely
silent while volume indicators behaved normally.

```sh
wpctl status
# Audio → Sinks: only "虚拟输出" (auto_null), no ALSA device at all

systemctl --user status wireplumber
# failed (Result: start-limit-hit)
# Process: ExecStart=.../bin/wireplumber (code=exited, status=78)
```

The hardware side was healthy, which is what localizes the failure to userspace:

```sh
aplay -l
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 0: MultiMedia1 Playback
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 1: MultiMedia2 Playback
# card 0: XiaomiPad6SPro [Xiaomi-Pad6SPro], device 2: MultiMedia3 Capture

speaker-test -D hw:0,0 -c 2 -t sine -l 1   # audible
```

Audible output from `speaker-test -D hw:0,0` proves the stage-1 kernel modules, the ADSP
firmware, the UCM routing, and the enable sequence for all six WSA amplifiers work.

## Root cause

`nixos/configuration.nix` declared the `92-sheng-speaker-eq` filter-chain as:

```nix
{
  name = "libpipewire-module-filter-chain";
  type = "pw-module";        # wrong
  arguments = { ... };
  provides = "filter.sink.sheng-speaker-eq";
}
```

`type = "pw-module"` loads the module into **WirePlumber's own main `pw_context`**, and
that context only loads three modules (`share/wireplumber/wireplumber.conf`):

```json
context.modules = [
  { name = libpipewire-module-rt ... },
  { name = libpipewire-module-protocol-native },
  { name = libpipewire-module-metadata }
]
```

`libpipewire-module-adapter` is not among them, so the `adapter` factory does not exist
there. module-filter-chain creates its two nodes with `pw_stream`, and
`pw_stream_connect()` does:

```c
/* src/pipewire/stream.c:2199-2203 */
factory = pw_context_find_factory(impl->context, "adapter");
if (factory == NULL) {
    pw_log_error("%p: no adapter factory found", stream);
    res = -ENOENT;
    goto error_node;
}
```

Hence module initialization fails:

```
pw.stream: ...: no adapter factory found
pw.stream: ...: can't make node: No such file or directory
failed to load components: failed to load required component 'filter.sink.sheng-speaker-eq
  [pw-module: libpipewire-module-filter-chain]': Failed to load pipewire module ...: No such file or directory
systemd: wireplumber.service: Main process exited, code=exited, status=78/CONFIG
```

The component is listed as `required` in the profile, so WirePlumber exits, hits
`start-limit-hit` after five retries, and the session manager is gone: the ALSA monitor
never creates nodes, only `auto_null` remains, and every playback is silent.

## Why earlier flashes had sound

The configuration landed in `be0a805` (2026-07-26) and never changed until the nixpkgs
bump `8068eb8` (2026-09-23) moved it from 2026-06-10 to 2026-09-22, bringing wireplumber
0.5.14 → 0.5.17 and pipewire 1.6.5 → 1.6.8. Same config, both revisions, measured:

| nixpkgs | wireplumber / pipewire | `type = "pw-module"` |
| --- | --- | --- |
| `9ae611a4` (2026-06-10) | 0.5.14 / 1.6.5 | works: filter-chain nodes created, WirePlumber alive |
| `6774f7bc` (2026-09-22) | 0.5.17 / 1.6.8 | fails: `no adapter factory found`, exit 78 |

The reason is a semantics change in WirePlumber's component types. The 0.5.14
`components_and_profiles` documentation has **no `pw-module-client`** at all, only
`pw-module`; 0.5.17 splits it into two:

- `pw-module` — "loaded in WirePlumber's main `pw_context` … what protocol extensions and
  object factories need";
- `pw-module-client` — "loaded in the *client context* … **this is the right type for
  modules that process media, such as `libpipewire-module-loopback`,
  `libpipewire-module-filter-chain` and `libpipewire-module-combine-stream`**".

Upstream's own `smart-equalizer.conf` example uses `pw-module-client`.

## Fix

`c0bcbac` changes `type` to `pw-module-client`. The client context is created from
PipeWire's `client.conf`, which does load the adapter module:

```
share/pipewire/client.conf:78
    { name = libpipewire-module-adapter
```

## Recovery on an already-flashed image

With shell access to a flashed device, a user-level drop-in restores sound without any
rebuild. WirePlumber reads `$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d/*.conf`:

```sh
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cat > ~/.config/wireplumber/wireplumber.conf.d/99-sheng-eq-fix.conf <<'EOF'
wireplumber.profiles = { main = { "filter.sink.sheng-speaker-eq" = disabled } }
EOF
systemctl --user restart wireplumber
wpctl status        # Sinks should now list alsa_output.platform-sound.HiFi__Speaker__sink
```

The trade-off is losing the speaker EQ (audio works, just untuned). Two caveats:

- **Redefining `wireplumber.components` in a user config does not work.** Measured: the
  array does not replace the system one and the broken component is still loaded. Only
  scalar overrides such as `wireplumber.profiles` take effect.
- To keep the EQ as well, disable the original component in user config and add a second
  component with a new name (e.g. `sheng.speaker-eq-fixed`), `type = "pw-module-client"`,
  the same arguments, marked `required`. The filter-chain nodes are created as expected.

The two complete paths (neither touches `boot_b`):

```sh
# stage-2 only, rebuilt on the device (use the remote/branch your image came from)
git clone <nixos-sheng repository> ~/nixos-sheng
cd ~/nixos-sheng && git checkout <matching branch>
sudo sheng-nixos-rebuild "$PWD/nixos#sheng-niri"
# after it succeeds, remove the emergency drop-in or the EQ stays disabled:
rm ~/.config/wireplumber/wireplumber.conf.d/99-sheng-eq-fix.conf && systemctl --user restart wireplumber
```

Or simply flash a CI-built rootfs image that contains the fix to the `linux` partition
(the home directory is replaced, so the drop-in disappears together with it).

## Offline reproduction (no device needed)

Running private PipeWire/WirePlumber instances with the conf.d files NixOS actually
generates reproduces and verifies the bug:

```sh
# 1. materialize the generated configuration (each key/value is a conf.d file body)
nix eval --json --impure --expr '
  let f = builtins.getFlake "/path/to/nixos-sheng/nixos";
      s = f.nixosConfigurations.sheng-niri;
  in s.config.services.pipewire.wireplumber.extraConfig."92-sheng-speaker-eq"' \
  | jq -r 'to_entries[] | "\(.key) = \(.value|tojson)"' > eq.conf

# 2. private runtime dir and private XDG_CONFIG_HOME
mkdir -p /tmp/wp/runtime /tmp/wp/config/wireplumber/wireplumber.conf.d
cp eq.conf /tmp/wp/config/wireplumber/wireplumber.conf.d/92-sheng-speaker-eq.conf
export XDG_RUNTIME_DIR=/tmp/wp/runtime XDG_CONFIG_HOME=/tmp/wp/config

pipewire & sleep 3; wireplumber & sleep 6
wpctl status
```

`pw-module` yields exit 78 and the error above; `pw-module-client` yields:

```
Filters:
  - filter-chain-…
    … input.filter.sink.sheng-speaker-eq     [Audio/Sink]
    … output.filter.sink.sheng-speaker-eq    [Stream/Output/Audio]
```

Creating a fake sink with the same name as `filter.smart.target` additionally confirms the
smart filter is attached to its intended device:

```sh
pw-cli create-node adapter '{ factory.name=support.null-audio-sink \
  node.name=alsa_output.platform-sound.HiFi__Speaker__sink \
  node.description="Fake Speaker" media.class=Audio/Sink object.linger=true \
  audio.position=[ FL FR ] }'
pw-link -l | grep -A2 filter.sink.sheng-speaker-eq
# output.filter.sink.sheng-speaker-eq:output_FL |-> alsa_output...:playback_FL
```

## Diagnostic commands

```sh
aplay -l; arecord -l; cat /proc/asound/cards
wpctl status
systemctl --user status pipewire pipewire-pulse wireplumber --no-pager
journalctl --user -u wireplumber -b --no-pager | tail -80
speaker-test -D hw:0,0 -c 2 -t sine -l 1        # bypass userspace, hit ALSA directly
```

Reading: `speaker-test` is audible but `wpctl` shows no sink → userspace problem; check
whether wireplumber failed. `speaker-test` is silent too → check module loading
(`sheng-audio-modules.service` runs `modprobe ... || true` and silently tolerates
failures), the UCM name match, and amplifier enablement.

## Scope

- The failure only affects stage-2 (rootfs). It does not involve the kernel, DTB, initrd,
  or boot cmdline, so `boot_b` does not need reflashing.
- Rollback: `git revert c0bcbac`.
