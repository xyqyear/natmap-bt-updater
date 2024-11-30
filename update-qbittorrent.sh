#!/bin/bash

# reference: https://github.com/wits-fe/bittorrent-NAT-hole-punching/blob/main/update-qb.sh

qbittorrent_host="192.168.0.0"
qbittorrent_port="9091"
target_inner_port="35689"
username="username"
password="password"
redirect_rule_name="qbittorrent-forward"

retry_interval=60
retry_times=2400

# params from natmap

ip=$1
port=$2
_ip4p=$3
inner_port=$4
protocol=$5

# if the target inner port is not the same as the inner port, then exit
if [ "$target_inner_port" != "$inner_port" ]; then
    exit 1
fi

pid_file="/var/run/update-qbittorrent.pid"

# if the pid file exists, kill the process
if [ -f "$pid_file" ]; then
    oldpid=$(cat "$pid_file")
    if kill -0 "$oldpid" >/dev/null 2>&1; then
        kill -9 "$oldpid"
    else
        rm "$pid_file"
    fi
fi

echo $$ >"$pid_file"

# retry for $retry_times times
while [ $retry_times -gt 0 ]; do
    # get session id
    qb_cookie=$(curl -m 3 -s -i --data "username=$username&password=$password" http://$qbittorrent_host:$qbittorrent_port/api/v2/auth/login | grep -i set-cookie | cut -c13-48)
    # if session id is found

    if [[ $(expr match "$qb_cookie" '.\+=') -gt 3 ]]; then
        echo "Update qBittorrent listen port to $port"
        curl -m 3 -s -X POST -b "$qb_cookie" -d 'json={"listen_port":"'$port'","announce_ip":"'$ip'"}' "http://$qbittorrent_host:$qbittorrent_port/api/v2/app/setPreferences" &>/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
    fi

    sleep $retry_interval
    retry_times=$((retry_times - 1))
done

# if the port is not set successfully, then exit
if [ $retry_times -eq 0 ]; then
    rm "$pid_file"
    exit 1
fi

# we delete the pid file so that it won't get killed while setting firewall rules
rm "$pid_file"

# update openwrt port forwarding settings with uci
found_line=$(uci show firewall | grep "firewall.@redirect\[\d\].name='$redirect_rule_name'" | sed -n "s/^firewall.@redirect\[\([0-9]*\)\].*$/\1/p")

# if the rule is not found, then add it
if [ -z "$found_line" ]; then
    uci add firewall redirect
    uci set firewall.@redirect[-1].name="$redirect_rule_name"
    uci set firewall.@redirect[-1].src="wan"
    uci set firewall.@redirect[-1].proto="$protocol"
    uci set firewall.@redirect[-1].src_dport="$inner_port"
    uci set firewall.@redirect[-1].dest_ip="$qbittorrent_host"
    uci set firewall.@redirect[-1].dest_port="$port"
    uci set firewall.@redirect[-1].target="DNAT"
    uci set firewall.@redirect[-1].dest="lan"
    uci commit firewall
    service firewall reload &>/dev/null
else
    # if the rule is found, then update it
    uci set firewall.@redirect["$found_line"].dest_port="$port"
    uci commit firewall
    service firewall reload &>/dev/null
fi
