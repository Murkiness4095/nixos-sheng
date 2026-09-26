# ---
# Module: sheng-local sshd LAN exemption
# Description: Keep OpenSSH per-source penalties from locking a LAN client out of the device
# Scope: System
# Notes:
# - OpenSSH 9.8+ 默认开启 PerSourcePenalties：同源地址一次认证失败就对该 /32 记惩罚
#   （authfail 基础 5s、min 15s、max 600s），期间后续连接在 banner 阶段直接被
#   RST，客户端只看到 `kex_exchange_identification: read: Connection reset by peer`，
#   而且每次重试都会续期。
# - 本设备重刷过 rootfs，客户端 known_hosts 里旧 host key 不匹配时会走一次失败认证，
#   于是这台开发机的地址被拉黑，表现为“突然再也 ssh 不上”。
# - 这里只豁免私有网段/回环：公网来源仍然保留惩罚保护，局域网内不会再因为一次
#   误认证被锁在外面。
# - 上游若自行处理该选项，本文件可删。
# ---
{ lib, ... }:

{
  services.openssh.settings.PerSourcePenaltyExemptList = lib.mkDefault
    "127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fe80::/10,fd00::/8";
}
