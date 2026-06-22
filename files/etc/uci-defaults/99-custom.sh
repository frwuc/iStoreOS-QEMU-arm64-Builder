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
else
    # 自动检测：从 WAN 口 DHCP 获取的网关推断网段
    echo "No LAN IP configured, auto-detecting..." >> $LOG
    # 等待 WAN 获取 DHCP
    for i in $(seq 1 30); do
        GATEWAY=$(uci get network.wan.gateway 2>/dev/null)
        if [ -n "$GATEWAY" ] && [ "$GATEWAY" != "0.0.0.0" ]; then
            break
        fi
        sleep 2
    done

    if [ -n "$GATEWAY" ] && [ "$GATEWAY" != "0.0.0.0" ]; then
        # 取网关的前三段，LAN 设为 .100
        SUBNET=$(echo "$GATEWAY" | sed 's/\.[0-9]*$//')
        LAN_IP="${SUBNET}.100"
        echo "Auto-detected LAN IP: $LAN_IP (gateway: $GATEWAY)" >> $LOG
    else
        # 默认 IP
        LAN_IP="192.168.100.1"
        echo "Fallback to default LAN IP: $LAN_IP" >> $LOG
    fi
fi

# 配置 LAN
uci set network.lan.ipaddr="$LAN_IP"
uci set network.lan.netmask="255.255.255.0"
uci commit network

# 重启网络
ifconfig br-lan "$LAN_IP" netmask 255.255.255.0 2>/dev/null

echo "LAN IP set to $LAN_IP at $(date)" >> $LOG

exit 0
