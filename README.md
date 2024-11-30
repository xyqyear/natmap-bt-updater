# Port Forwarding Update Scripts

This project contains Bash scripts designed to update port forwarding settings for BitTorrent clients running on an OpenWrt router. The scripts automate the process of setting the peer port for the clients and updating the corresponding firewall rules on the router.

## Scripts

- `update-transmission.sh`: Updates port forwarding settings for the Transmission BitTorrent client.
- `update-qbittorrent.sh`: Updates port forwarding settings for the qBittorrent client. (WIP)

## Usage

Each script takes parameters from the `natmap` tool and updates the OpenWrt firewall rules accordingly.

## Reference

[bittorrent-NAT-hole-punching](https://github.com/wits-fe/bittorrent-NAT-hole-punching/blob/main/update-tr.sh)

The difference between this project and _bittorrent-NAT-hole-punching_ is I use uci firewall forwarding rules for forwarding the traffic instead of iptables rules. Therefore, this should be compatible with both iptables and nftables i think?
