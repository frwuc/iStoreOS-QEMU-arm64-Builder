#!/bin/sh

# 日志文件
LOG="/tmp/uci-defaults-log.txt"
echo "Running 99-custom.sh at $(date)" >> $LOG

# 读取构建时写入的 LAN IP 配置
LAN_IP=""
if [ -f /etc/config/lan-settings ]; then
    . /etc/config/lan-settings
    echo "Read lan-settings: LAN_IPADDR=$LAN_IPADDR" >> $LOG
fi

if [ -n "$LAN_IPADDR" ]; then
    # 用户指定了 LAN IP
    LAN_IP="$LAN_IPADDR"
    echo "Using configured LAN IP: $LAN_IP" >> $LOG
    uci set network.lan.ipaddr="$LAN_IP"
    uci set network.lan.netmask="255.255.255.0"
    uci commit network
    ifconfig br-lan "$LAN_IP" netmask 255.255.255.0 2>/dev/null
else
    # 自动检测：等待 DHCP 获取默认路由网关，推断网段
    echo "No LAN IP configured, auto-detecting..." >> $LOG
    for i in $(seq 1 30); do
        GATEWAY=$(uci get network.wan.gateway 2>/dev/null)
        if [ -z "$GATEWAY" ] || [ "$GATEWAY" = "0.0.0.0" ]; then
            GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}')
        fi
        if [ -n "$GATEWAY" ]; then
            SUBNET=$(echo "$GATEWAY" | sed 's/\.[0-9]*$//')
            LAN_IP="${SUBNET}.100"
            echo "Auto-detected LAN IP: $LAN_IP (gateway: $GATEWAY)" >> $LOG
            uci set network.lan.ipaddr="$LAN_IP"
            uci set network.lan.netmask="255.255.255.0"
            uci commit network
            ifconfig br-lan "$LAN_IP" netmask 255.255.255.0 2>/dev/null
            break
        fi
        sleep 2
    done

    if [ -z "$LAN_IP" ]; then
        # 无 WAN 口（单网卡桥接模式），LAN 走 DHCP
        echo "No gateway detected, switching LAN to DHCP..." >> $LOG
        uci set network.lan.proto="dhcp"
        uci delete network.lan.ipaddr 2>/dev/null
        uci delete network.lan.netmask 2>/dev/null
        uci commit network
        ifconfig br-lan 0.0.0.0 2>/dev/null
        udhcpc -i br-lan -q 2>/dev/null
    fi
fi

echo "LAN setup complete at $(date)" >> $LOG

exit 0
