# Add your own Proton VPN configuration

Mx VPN is a third-party WireGuard client. It does not include a VPN account or shared VPN credentials, and it is not affiliated with Proton.

1. Create or sign in to your own Proton VPN account at https://account.protonvpn.com/downloads.
2. Find **WireGuard configuration**, enter a device name, and select your platform.
3. Select **Free server configs**. For Houston, the live Proton server list on October 12, 2026 identifies **US-FREE#44**, **US-FREE#45**, and **US-FREE#47** as Houston servers. Availability and locations can change. US-FREE#35 is Seattle.
4. Click **Create** beside your selected server, then **Download**. Keep this `.conf` private: it contains your VPN private key. Generate a separate configuration for each device, and follow your Proton plan's simultaneous-connection limits.
5. Open Mx VPN, import the `.conf`, name the profile, and connect. On Android, accept the VPN permission. On Windows, use **Import tunnel(s) from file**, then **Activate**. On macOS, use the profile import action, then **Connect**.
6. Confirm that the public IP changes. A successful connection does not by itself prove kill-switch protection or absence of IPv6/DNS leaks. If you require a particular city, check the connected public IP's location as well; geolocation databases can disagree.

Use a single-peer full-tunnel WireGuard profile: `AllowedIPs` includes `0.0.0.0/0` and, when IPv6 is configured, `::/0`; tunnel DNS is required. Mx import rejects executable configuration hooks.

Do not upload configurations to GitHub, post private keys, or use another person's configuration. Delete unencrypted download copies after a verified import, keeping any necessary backup in encrypted storage. Revoke a configuration in your Proton account if it is exposed.

Linux Mint: install `mxvpn_0.1.0-1_all.deb` from the same release page, open Mx VPN from the applications menu, click **Import config**, choose your own private `.conf`, then **Connect**. Use **Disconnect** to stop it. The package works through NetworkManager and uses the normal desktop authorization prompt. It contains no shared provider credentials.
