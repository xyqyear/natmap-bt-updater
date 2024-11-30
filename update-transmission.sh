#!/bin/bash

# reference: https://github.com/wits-fe/bittorrent-NAT-hole-punching/blob/main/update-tr.sh

transmission_host="192.168.0.0"
transmission_port="9091"
target_inner_port="35689"
username="username"
password="password"
redirect_rule_name="transmission-forward"

retry_interval=60
retry_times=2400

# params from natmap

_ip=$1
port=$2
_ip4p=$3
inner_port=$4
protocol=$5

# if the target inner port is not the same as the inner port, then exit
if [ "$target_inner_port" != "$inner_port" ]; then
    exit 1
fi

pid_file="/var/run/natmap_transmission_updater.pid"

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
    session_id_header=$(curl -m 3 -s -u $username:$password http://$transmission_host:$transmission_port/transmission/rpc | sed -n 's/.*<code>\(.*\)<\/code>.*/\1/p')
    # if session id is found
    if echo "$session_id_header" | grep -q -E "^X-Transmission-Session-Id: .+$"; then
        curl -m 3 -s -u $username:$password -X POST -H "$session_id_header" -d '{"method":"session-set","arguments":{"peer-port":'"$port"'}}' "http://$transmission_host:$transmission_port/transmission/rpc" &>/dev/null

        # if the port is set successfully, then break
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
    uci set firewall.@redirect[-1].dest_ip="$transmission_host"
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
