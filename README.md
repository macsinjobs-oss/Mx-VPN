# Mx VPN

A personal WireGuard VPN client with a public-IP dashboard, profile controls, duration, speed and transfer totals. Mx VPN is based on Amnezia VPN on macOS and WireGuard on Android/Windows. Original license and attribution notices are retained.

## Downloads

All released downloads belong at [v0.1.0](https://github.com/macsinjobs-oss/Mx-VPN/releases/tag/v0.1.0).

- Android: signed ARM64 APK, Android 7 or later. Real connection and profile flows tested on an ARM64 emulator; physical-phone testing remains pending.
- macOS: Apple Silicon development DMG, macOS 27 or later. Apple Development signing; not notarized, and installation on another Mac is unverified. Read the package's installation notes before installing its privileged networking helper.
- Windows: x64 and ARM64 portable executables. Cross-compiled and unit-tested; Windows installation, driver, interface and real connection remain untested.
- Linux: no Mx VPN `.deb` yet. Current personal backend supports macOS; a Linux port and runtime verification are required.

## Get a VPN configuration

Mx VPN does not include a VPN account or private provider configuration. [Follow the configuration guide](mx/CONFIG-GUIDE.md) to download a WireGuard profile from your own Proton account and import it. As of October 12, 2026, Proton identifies US-FREE#44, #45 and #47 as active free Houston servers. Availability and IP geolocation can change.

Do not share or publish `.conf` files: they contain private keys. Generate one profile per device and follow your provider's connection limits.

## Verification limits

Prior tests covered macOS real-tunnel/profile flows, 4 CTest suites, Android emulator real-tunnel/profile flows, 26 JVM tests and 5 encrypted-storage instrumentation tests. Windows has 6 dashboard unit tests, not Windows runtime verification. Kill-switch, exhaustive IPv6/DNS leak, network handover and sleep/wake claims are not established.

## Source and licenses

The macOS source snapshot derives from Amnezia client 4c2e950 and the Mx modifications included in this release. Third-party dependency source is included where previously tracked as submodules. See LICENSE and upstream notices. Android and Windows use separate WireGuard-derived codebases; corresponding source archives must accompany their binaries.

Mx VPN is not affiliated with Proton, Amnezia or WireGuard.
