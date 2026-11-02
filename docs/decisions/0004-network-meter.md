# 0004. The network meter counts Ethernet-type interfaces and lights an arrow above 1 KB/s

- **Date:** 2026-11-01
- **Status:** accepted

## Context

The network meter shows one number per direction, but a Mac has many interfaces. On an M1 Max
running macOS 27, `NET_RT_IFLIST2` lists about twenty: the loopback, Wi-Fi (`en0`), Thunderbolt
ports and their bridge, AirDrop's `awdl0` and `llw0`, and four `utun` tunnels. A VPN's traffic
crosses both its tunnel and the Wi-Fi or Ethernet interface under it, so adding up every
interface counts it twice, and the loopback carries traffic that never leaves the Mac.
Yujitach's fork offers a preferred-interface setting, which the lean scope leaves for later.
An idle Mac also always has a trickle of traffic, such as Bonjour and push notifications.

## Decision

The meter adds up the interfaces of type `IFT_ETHER` that are up, which includes Wi-Fi, and
leaves out tunnels (`IFT_OTHER`), bridges (`IFT_BRIDGE`, whose members are counted) and the
loopback. An arrow lights when its direction moves at least 1,000 bytes a second
(`NetworkDrawState.activeBytesPerSecond`).

## Alternatives considered

- **The primary interface only, from SystemConfiguration:** needs a watch for the primary
  interface changing, and misses traffic on a second interface, such as Ethernet and Wi-Fi both
  up. Fits better as the preferred-interface setting.
- **Every interface but the loopback:** counts VPN traffic twice.
- **An arrow lit for any traffic:** stays lit on an idle Mac, so it says nothing, and redraws
  more.

## Consequences

- A connection through an interface of another type, such as a cellular modem, isn't counted.
  The menu still lists it with its own rates.
- The preferred-interface setting, when it comes, replaces the type rule for the chosen one.
